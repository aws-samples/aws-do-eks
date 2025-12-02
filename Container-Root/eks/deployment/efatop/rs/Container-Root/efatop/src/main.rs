use anyhow::Result;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::{Backend, CrosstermBackend},
    layout::{Constraint, Direction, Layout},
    style::{Color, Style},
    symbols,
    widgets::{Axis, Block, Borders, Chart, Dataset, GraphType, Paragraph, Table, Row, Cell},
    Frame, Terminal,
};
use std::collections::HashMap;
use std::fs;
use std::io;
use std::path::Path;
use std::time::{Duration, Instant};
use tokio::time::sleep;

#[derive(Debug, Clone, PartialEq)]
enum ViewMode {
    Individual,
    Aggregated,
    Table,
    Counters,
    Status,
}

#[derive(Debug, Clone)]
struct EfaStats {
    counters: HashMap<String, u64>,
    timestamp: Instant,
}

struct EfaMonitor {
    adapters: Vec<String>,
    previous_stats: HashMap<String, EfaStats>,
    history: HashMap<String, Vec<(f64, HashMap<String, f64>)>>, // (time, counter_rates)
    aggregated_history: Vec<(f64, HashMap<String, f64>)>, // (time, total_counter_rates)
    start_time: Instant,
    view_mode: ViewMode,
    available_counters: Vec<String>,
    selected_counters: Vec<bool>,
    cursor_position: usize,
    table_scroll_offset: usize,
    max_rates: HashMap<String, HashMap<String, f64>>, // adapter -> counter -> max_rate
    aggregated_max_rates: HashMap<String, f64>, // counter -> max_rate
}

impl EfaMonitor {
    fn new() -> Result<Self> {
        let adapters = Self::discover_efa_adapters()?;
        let available_counters = Self::discover_counters(&adapters)?;
        let selected_counters = available_counters.iter()
            .map(|c| c == "tx_bytes" || c == "rx_bytes")
            .collect();
        
        Ok(Self {
            adapters,
            previous_stats: HashMap::new(),
            history: HashMap::new(),
            aggregated_history: Vec::new(),
            start_time: Instant::now(),
            view_mode: ViewMode::Individual,
            available_counters,
            selected_counters,
            cursor_position: 0,
            table_scroll_offset: 0,
            max_rates: HashMap::new(),
            aggregated_max_rates: HashMap::new(),
        })
    }

    fn reset(&mut self) {
        self.previous_stats.clear();
        self.history.clear();
        self.aggregated_history.clear();
        self.max_rates.clear();
        self.aggregated_max_rates.clear();
        self.start_time = Instant::now();
    }

    fn discover_efa_adapters() -> Result<Vec<String>> {
        let infiniband_path = Path::new("/sys/class/infiniband");
        let mut adapters = Vec::new();

        if !infiniband_path.exists() {
            return Ok(adapters);
        }

        for entry in fs::read_dir(infiniband_path)? {
            let entry = entry?;
            let name = entry.file_name().to_string_lossy().to_string();
            adapters.push(name);
        }

        adapters.sort_by_key(|name| {
            name.chars()
                .filter(|c| c.is_ascii_digit())
                .collect::<String>()
                .parse::<u32>()
                .unwrap_or(0)
        });

        Ok(adapters)
    }

    fn discover_counters(adapters: &[String]) -> Result<Vec<String>> {
        if let Some(adapter) = adapters.first() {
            let counters_path = format!("/sys/class/infiniband/{}/ports/1/hw_counters", adapter);
            let mut counters = Vec::new();
            
            if let Ok(entries) = fs::read_dir(&counters_path) {
                for entry in entries {
                    if let Ok(entry) = entry {
                        let name = entry.file_name().to_string_lossy().to_string();
                        counters.push(name);
                    }
                }
            }
            
            counters.sort();
            Ok(counters)
        } else {
            let mut counters = vec!["tx_bytes".to_string(), "rx_bytes".to_string()];
            counters.sort();
            Ok(counters)
        }
    }

    fn read_counter(adapter: &str, counter: &str) -> Result<u64> {
        let path = format!("/sys/class/infiniband/{}/ports/1/hw_counters/{}", adapter, counter);
        let content = fs::read_to_string(&path)?;
        Ok(content.trim().parse()?)
    }

    fn read_status_file(path: &str) -> String {
        fs::read_to_string(path).unwrap_or_else(|_| "N/A".to_string()).trim().to_string()
    }

    fn collect_stats(&mut self) -> Result<()> {
        let now = Instant::now();
        let elapsed = now.duration_since(self.start_time).as_secs_f64();

        for adapter in &self.adapters {
            let mut current_counters = HashMap::new();
            
            for (i, counter) in self.available_counters.iter().enumerate() {
                if *self.selected_counters.get(i).unwrap_or(&false) {
                    let value = Self::read_counter(adapter, counter).unwrap_or(0);
                    current_counters.insert(counter.clone(), value);
                }
            }

            let current_stats = EfaStats {
                counters: current_counters.clone(),
                timestamp: now,
            };

            let mut rates = HashMap::new();
            if let Some(prev) = self.previous_stats.get(adapter) {
                let time_diff = now.duration_since(prev.timestamp).as_secs_f64();
                for (counter, &current_value) in &current_counters {
                    if let Some(&prev_value) = prev.counters.get(counter) {
                        let rate = if time_diff > 0.0 {
                            (current_value.saturating_sub(prev_value) as f64) / time_diff / 1_000_000.0
                        } else {
                            0.0
                        };
                        rates.insert(counter.clone(), rate);
                        
                        // Update max rates
                        let adapter_max = self.max_rates.entry(adapter.clone()).or_insert_with(HashMap::new);
                        let current_max = adapter_max.entry(counter.clone()).or_insert(0.0);
                        *current_max = current_max.max(rate);
                    }
                }
            }

            let history = self.history.entry(adapter.clone()).or_insert_with(Vec::new);
            history.push((elapsed, rates));
            
            if history.len() > 600 {
                history.remove(0);
            }

            self.previous_stats.insert(adapter.clone(), current_stats);
        }

        // Calculate aggregated totals
        let mut total_rates = HashMap::new();
        for counter in &self.available_counters {
            let total: f64 = self.history.values()
                .filter_map(|h| h.last())
                .filter_map(|(_, rates)| rates.get(counter))
                .sum();
            if total > 0.0 {
                total_rates.insert(counter.clone(), total);
                
                // Update aggregated max rates
                let current_max = self.aggregated_max_rates.entry(counter.clone()).or_insert(0.0);
                *current_max = current_max.max(total);
            }
        }
        
        self.aggregated_history.push((elapsed, total_rates));
        if self.aggregated_history.len() > 600 {
            self.aggregated_history.remove(0);
        }

        Ok(())
    }

    fn ui_individual(&self, f: &mut Frame, main_chunks: &[ratatui::layout::Rect]) {
        let chunks = if self.adapters.len() == 1 {
            vec![main_chunks[0]]
        } else {
            let cols = (self.adapters.len() as f64).sqrt().ceil() as u16;
            let rows = (self.adapters.len() as f64 / cols as f64).ceil() as u16;
            
            let row_chunks = Layout::default()
                .direction(Direction::Vertical)
                .constraints(vec![Constraint::Percentage(100 / rows); rows as usize])
                .split(main_chunks[0]);
            
            let mut chunks = Vec::new();
            for row_chunk in row_chunks.iter() {
                let col_chunks = Layout::default()
                    .direction(Direction::Horizontal)
                    .constraints(vec![Constraint::Percentage(100 / cols); cols as usize])
                    .split(*row_chunk);
                chunks.extend(col_chunks.iter());
            }
            chunks
        };

        for (i, adapter) in self.adapters.iter().enumerate() {
            if i >= chunks.len() {
                break;
            }

            if let Some(history) = self.history.get(adapter) {
                let colors = [Color::Green, Color::Red, Color::Blue, Color::Yellow, Color::Magenta, Color::Cyan];
                let mut color_idx = 0;
                
                let mut max_rate = 1.0f64;
                let mut current_rates = HashMap::new();
                let mut all_data = Vec::new();
                
                for (i, counter) in self.available_counters.iter().enumerate() {
                    if *self.selected_counters.get(i).unwrap_or(&false) {
                        let data: Vec<(f64, f64)> = history.iter()
                            .map(|(t, rates)| (*t, *rates.get(counter).unwrap_or(&0.0)))
                            .collect();
                        
                        if let Some((_, rates)) = history.last() {
                            if let Some(&rate) = rates.get(counter) {
                                current_rates.insert(counter, rate);
                            }
                        }
                        
                        // Use historical max rate to maintain consistent scale
                        if let Some(adapter_max) = self.max_rates.get(adapter) {
                            if let Some(&historical_max) = adapter_max.get(counter) {
                                max_rate = max_rate.max(historical_max);
                            }
                        }
                        
                        all_data.push((counter.clone(), data, colors[color_idx % colors.len()]));
                        color_idx += 1;
                    }
                }
                
                let datasets: Vec<Dataset> = all_data.iter().map(|(counter, data, color)| {
                    Dataset::default()
                        .name(counter.as_str())
                        .marker(symbols::Marker::Braille)
                        .style(Style::default().fg(*color))
                        .graph_type(GraphType::Line)
                        .data(data)
                }).collect();
                
                let mut sorted_rates: Vec<_> = current_rates.iter().collect();
                sorted_rates.sort_by_key(|(k, _)| *k);
                let current_str: String = sorted_rates.iter()
                    .map(|(k, v)| format!("{}:{:.1}", k, v))
                    .collect::<Vec<_>>()
                    .join(" ");
                
                let title = format!("{} {} | Max:{:.1} | {}", i + 1, adapter, max_rate, current_str);

                let chart_width = chunks[i].width.saturating_sub(4) as f64; // Account for borders
                let time_window = (chart_width * 0.1).max(10.0); // ~0.1 seconds per character width, min 10s
                let time_range = if history.is_empty() {
                    [0.0, time_window]
                } else {
                    let max_time = history.last().unwrap().0;
                    [max_time - time_window, max_time]
                };

                let chart = Chart::new(datasets)
                    .block(Block::default().title(title.as_str()).borders(Borders::ALL))
                    .x_axis(Axis::default().title("Time (s)").bounds(time_range))
                    .y_axis(Axis::default().title("MB/s").bounds([0.0, max_rate * 1.1]));

                f.render_widget(chart, chunks[i]);
            }
        }

    }

    fn ui_table(&self, f: &mut Frame, main_chunks: &[ratatui::layout::Rect]) {
        let mut rows = Vec::new();
        
        for (i, adapter) in self.adapters.iter().enumerate() {
            if let Some(history) = self.history.get(adapter) {
                let mut cells = vec![Cell::from((i + 1).to_string()), Cell::from(adapter.clone())];
                
                if let Some((_, rates)) = history.last() {
                    let mut selected_counters: Vec<&String> = self.available_counters.iter()
                        .enumerate()
                        .filter(|(i, _)| *self.selected_counters.get(*i).unwrap_or(&false))
                        .map(|(_, counter)| counter)
                        .collect();
                    selected_counters.sort();
                    
                    for counter in selected_counters {
                        let rate = rates.get(counter).unwrap_or(&0.0);
                        let absolute_value = if let Some(stats) = self.previous_stats.get(adapter) {
                            stats.counters.get(counter).unwrap_or(&0)
                        } else {
                            &0
                        };
                        cells.push(Cell::from(format!("{} ({:.1}/s)", absolute_value, rate)));
                    }
                }
                
                let row_style = if i % 2 == 0 {
                    Style::default()
                } else {
                    Style::default().bg(Color::DarkGray)
                };
                
                rows.push(Row::new(cells).style(row_style));
            }
        }
        
        let mut headers: Vec<String> = vec!["#".to_string(), "Adapter".to_string()];
        let mut selected_counters: Vec<&String> = self.available_counters.iter()
            .enumerate()
            .filter(|(i, _)| *self.selected_counters.get(*i).unwrap_or(&false))
            .map(|(_, counter)| counter)
            .collect();
        selected_counters.sort();
        for counter in &selected_counters {
            headers.push(format!("{} (rate/s)", counter));
        }
        let header_refs: Vec<&str> = headers.iter().map(|s| s.as_str()).collect();
        
        let col_width = 100 / header_refs.len() as u16;
        let constraints: Vec<Constraint> = (0..header_refs.len()).map(|_| Constraint::Percentage(col_width)).collect();
        
        let visible_rows = main_chunks[0].height.saturating_sub(3) as usize; // Account for borders and header
        let total_rows = rows.len();
        let scroll_offset = self.table_scroll_offset.min(total_rows.saturating_sub(visible_rows));
        
        let visible_rows_slice = if total_rows > visible_rows {
            &rows[scroll_offset..scroll_offset.min(total_rows).min(scroll_offset + visible_rows)]
        } else {
            &rows
        };
        
        let title = if total_rows > visible_rows {
            format!("EFA Adapters Table ({}/{} rows)", scroll_offset + visible_rows_slice.len(), total_rows)
        } else {
            "EFA Adapters Table".to_string()
        };
        
        let table = Table::new(visible_rows_slice.to_vec(), &constraints)
            .header(Row::new(header_refs))
            .block(Block::default().title(title.as_str()).borders(Borders::ALL));
        
        f.render_widget(table, main_chunks[0]);
    }

    fn ui_status(&self, f: &mut Frame, main_chunks: &[ratatui::layout::Rect]) {
        let mut rows = Vec::new();
        
        for (i, adapter) in self.adapters.iter().enumerate() {
            let rate = Self::read_status_file(&format!("/sys/class/infiniband/{}/ports/1/rate", adapter));
            let state = Self::read_status_file(&format!("/sys/class/infiniband/{}/ports/1/state", adapter));
            let phys_state = Self::read_status_file(&format!("/sys/class/infiniband/{}/ports/1/phys_state", adapter));
            let device = Self::read_status_file(&format!("/sys/class/infiniband/{}/device/device", adapter));
            let node_guid = Self::read_status_file(&format!("/sys/class/infiniband/{}/node_guid", adapter));
            let gid = Self::read_status_file(&format!("/sys/class/infiniband/{}/ports/1/gids/0", adapter));
            
            let cells = vec![
                Cell::from((i + 1).to_string()),
                Cell::from(adapter.clone()),
                Cell::from(rate),
                Cell::from(state),
                Cell::from(phys_state),
                Cell::from(device),
                Cell::from(node_guid),
                Cell::from(gid),
            ];
            
            let row_style = if i % 2 == 0 {
                Style::default()
            } else {
                Style::default().bg(Color::DarkGray)
            };
            
            rows.push(Row::new(cells).style(row_style));
        }
        
        let headers = vec!["#", "Adapter", "Rate", "State", "Phys State", "Device", "Node GUID", "GID"];
        let constraints = vec![
            Constraint::Length(6),   // #
            Constraint::Length(13),  // Adapter
            Constraint::Length(11),  // Rate
            Constraint::Length(11),  // State
            Constraint::Length(13),  // Phys State
            Constraint::Length(11),  // Device
            Constraint::Length(23),  // Node GUID
            Constraint::Min(23),     // GID (remaining space)
        ];
        
        let table = Table::new(rows, &constraints)
            .header(Row::new(headers))
            .block(Block::default().title("EFA Adapters Status").borders(Borders::ALL));
        
        f.render_widget(table, main_chunks[0]);
    }

    fn ui_counters(&self, f: &mut Frame, main_chunks: &[ratatui::layout::Rect]) {
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Min(0), Constraint::Length(1)])
            .split(main_chunks[0]);
            
        let mut rows = Vec::new();
        
        for (i, counter) in self.available_counters.iter().enumerate() {
            let checkbox = if *self.selected_counters.get(i).unwrap_or(&false) {
                "[x]"
            } else {
                "[ ]"
            };
            
            let row_style = if i == self.cursor_position {
                Style::default().bg(Color::Blue)
            } else {
                Style::default()
            };
            
            rows.push(Row::new(vec![
                Cell::from(format!("{} {}", checkbox, counter)),
            ]).style(row_style));
        }
        
        let table = Table::new(rows, &[Constraint::Percentage(100)])
            .header(Row::new(vec!["Counter Selection"]))
            .block(Block::default().title("Counters").borders(Borders::ALL));
        
        f.render_widget(table, chunks[0]);
        
        let help = Paragraph::new("Up/Down arrow: navigate | Space bar: toggle counter on/off | Ctrl-a: select all counters | Ctrl-d: deselect all counters")
            .style(Style::default().fg(Color::Yellow));
        f.render_widget(help, chunks[1]);
    }

    fn ui_aggregated(&self, f: &mut Frame, main_chunks: &[ratatui::layout::Rect]) {
        let colors = [Color::Green, Color::Red, Color::Blue, Color::Yellow, Color::Magenta, Color::Cyan];
        let mut color_idx = 0;
        let mut max_rate = 1.0f64;
        let mut current_rates = HashMap::new();
        let mut all_data = Vec::new();
        
        for (i, counter) in self.available_counters.iter().enumerate() {
            if *self.selected_counters.get(i).unwrap_or(&false) {
                let data: Vec<(f64, f64)> = self.aggregated_history.iter()
                    .map(|(t, rates)| (*t, *rates.get(counter).unwrap_or(&0.0)))
                    .collect();
                
                if let Some((_, rates)) = self.aggregated_history.last() {
                    if let Some(&rate) = rates.get(counter) {
                        current_rates.insert(counter, rate);
                    }
                }
                
                // Use historical max rate to maintain consistent scale
                if let Some(&historical_max) = self.aggregated_max_rates.get(counter) {
                    max_rate = max_rate.max(historical_max);
                }
                
                all_data.push((counter.clone(), data, colors[color_idx % colors.len()]));
                color_idx += 1;
            }
        }
        
        let datasets: Vec<Dataset> = all_data.iter().map(|(counter, data, color)| {
            Dataset::default()
                .name(counter.as_str())
                .marker(symbols::Marker::Braille)
                .style(Style::default().fg(*color))
                .graph_type(GraphType::Line)
                .data(data)
        }).collect();
        
        let mut sorted_counters: Vec<_> = self.available_counters.iter()
            .enumerate()
            .filter(|(i, _)| *self.selected_counters.get(*i).unwrap_or(&false))
            .map(|(_, counter)| counter)
            .collect();
        sorted_counters.sort();
        
        let current_str: String = sorted_counters.iter()
            .map(|counter| {
                let rate = current_rates.get(counter).unwrap_or(&0.0);
                format!("{}:{:.1}", counter, rate)
            })
            .collect::<Vec<_>>()
            .join(" ");
        
        let title = format!("Aggregated View | Max:{:.1} | {}", max_rate, current_str);

        let chart_width = main_chunks[0].width.saturating_sub(4) as f64; // Account for borders
        let time_window = (chart_width * 0.1).max(10.0); // ~0.1 seconds per character width, min 10s
        let time_range = if self.aggregated_history.is_empty() {
            [0.0, time_window]
        } else {
            let max_time = self.aggregated_history.last().unwrap().0;
            [max_time - time_window, max_time]
        };

        let chart = Chart::new(datasets)
            .block(Block::default().title(title.as_str()).borders(Borders::ALL))
            .x_axis(Axis::default().title("Time (s)").bounds(time_range))
            .y_axis(Axis::default().title("MB/s").bounds([0.0, max_rate * 1.1]));

        f.render_widget(chart, main_chunks[0]);
    }

    fn ui(&self, f: &mut Frame) {
        let main_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Min(0), Constraint::Length(1)])
            .split(f.size());

        match self.view_mode {
            ViewMode::Individual => self.ui_individual(f, &main_chunks),
            ViewMode::Aggregated => self.ui_aggregated(f, &main_chunks),
            ViewMode::Table => self.ui_table(f, &main_chunks),
            ViewMode::Counters => self.ui_counters(f, &main_chunks),
            ViewMode::Status => self.ui_status(f, &main_chunks),
        }

        let menu = Paragraph::new("efatop v20251203 | 1 - Individual | 2 - Aggregated | 3 - Table | 4 - Counters | 5 - Status | 6 - Reset | q - Quit")
            .style(Style::default().fg(Color::White));
        f.render_widget(menu, main_chunks[1]);
    }
}

async fn run_app<B: Backend>(terminal: &mut Terminal<B>, mut monitor: EfaMonitor) -> Result<()> {
    loop {
        if monitor.view_mode != ViewMode::Counters {
            monitor.collect_stats()?;
        }
        terminal.draw(|f| monitor.ui(f))?;

        if event::poll(Duration::from_millis(10))? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('q') => return Ok(()),
                    KeyCode::Char('1') => monitor.view_mode = ViewMode::Individual,
                    KeyCode::Char('2') => monitor.view_mode = ViewMode::Aggregated,
                    KeyCode::Char('3') => monitor.view_mode = ViewMode::Table,
                    KeyCode::Char('4') => monitor.view_mode = ViewMode::Counters,
                    KeyCode::Char('5') => monitor.view_mode = ViewMode::Status,
                    KeyCode::Char('6') => monitor.reset(),
                    KeyCode::Up => {
                        if monitor.view_mode == ViewMode::Counters && monitor.cursor_position > 0 {
                            monitor.cursor_position -= 1;
                        } else if monitor.view_mode == ViewMode::Table && monitor.table_scroll_offset > 0 {
                            monitor.table_scroll_offset -= 1;
                        }
                    },
                    KeyCode::Down => {
                        if monitor.view_mode == ViewMode::Counters && monitor.cursor_position < monitor.available_counters.len().saturating_sub(1) {
                            monitor.cursor_position += 1;
                        } else if monitor.view_mode == ViewMode::Table {
                            let max_scroll = monitor.adapters.len().saturating_sub(1);
                            if monitor.table_scroll_offset < max_scroll {
                                monitor.table_scroll_offset += 1;
                            }
                        }
                    },
                    KeyCode::Char(' ') => {
                        if monitor.view_mode == ViewMode::Counters && monitor.cursor_position < monitor.selected_counters.len() {
                            monitor.selected_counters[monitor.cursor_position] = !monitor.selected_counters[monitor.cursor_position];
                        }
                    },
                    KeyCode::Char('a') => {
                        if monitor.view_mode == ViewMode::Counters && key.modifiers.contains(crossterm::event::KeyModifiers::CONTROL) {
                            // Ctrl-A: select all
                            for selected in &mut monitor.selected_counters {
                                *selected = true;
                            }
                        }
                    },
                    KeyCode::Char('d') => {
                        if monitor.view_mode == ViewMode::Counters && key.modifiers.contains(crossterm::event::KeyModifiers::CONTROL) {
                            // Ctrl-D: deselect all
                            for selected in &mut monitor.selected_counters {
                                *selected = false;
                            }
                        }
                    },
                    _ => {}
                }
            }
        }

        if monitor.view_mode == ViewMode::Counters {
            sleep(Duration::from_millis(16)).await;
        } else {
            sleep(Duration::from_millis(100)).await;
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let monitor = EfaMonitor::new()?;
    
    if monitor.adapters.is_empty() {
        println!("No EFA adapters found in /sys/class/infiniband");
        return Ok(());
    }

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let res = run_app(&mut terminal, monitor).await;

    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        println!("{:?}", err);
    }

    Ok(())
}