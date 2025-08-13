package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"gonum.org/v1/plot"
	"gonum.org/v1/plot/plotter"
	"gonum.org/v1/plot/vg"
	"image/color"
)

type model struct {
	adapters []string
	data     map[string][]uint64
	width    int
	height   int
	scroll   int
	columns  int
	rows     int
	statusView bool
	tableView bool
	configView bool
	counters []string
	selectedCounter int
	currentCounter string
}

type tickMsg time.Time

func tick() tea.Cmd {
	return tea.Tick(time.Second, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m model) Init() tea.Cmd {
	return tick()
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "up", "k":
			if m.configView {
				if m.selectedCounter > 0 {
					m.selectedCounter--
				}
			} else if m.scroll > 0 {
				m.scroll--
			}
		case "down", "j":
			if m.configView {
				if m.selectedCounter < len(m.counters)-1 {
					m.selectedCounter++
				}
			} else {
				m.scroll++
			}
		case "shift+up", "K":
			pageSize := (m.height - 6) / ((m.height - 6) / m.rows)
			if pageSize < 1 {
				pageSize = 1
			}
			m.scroll -= pageSize
			if m.scroll < 0 {
				m.scroll = 0
			}
		case "shift+down", "J":
			pageSize := (m.height - 6) / ((m.height - 6) / m.rows)
			if pageSize < 1 {
				pageSize = 1
			}
			m.scroll += pageSize
		case "1", "2", "3", "4", "5", "6", "7", "8":
			if cols, err := strconv.Atoi(msg.String()); err == nil {
				m.columns = cols
				m.scroll = 0
			}
		case "!": // shift + 1
			m.rows = 1
			m.scroll = 0
		case "@": // shift + 2
			m.rows = 2
			m.scroll = 0
		case "#": // shift + 3
			m.rows = 3
			m.scroll = 0
		case "$": // shift + 4
			m.rows = 4
			m.scroll = 0
		case "s":
			m.statusView = !m.statusView
			m.tableView = false
			m.configView = false
			m.scroll = 0
		case "m":
			m.statusView = false
			m.tableView = false
			m.configView = false
			m.scroll = 0
		case "t":
			m.tableView = !m.tableView
			m.statusView = false
			m.configView = false
			m.scroll = 0
		case "c":
			m.configView = !m.configView
			m.statusView = false
			m.tableView = false
			m.scroll = 0
			if m.configView && len(m.counters) == 0 {
				m.loadCounters()
			}
		case "enter":
			if m.configView && m.selectedCounter < len(m.counters) {
				m.currentCounter = m.counters[m.selectedCounter]
				m.configView = false
				m.data = make(map[string][]uint64) // Reset data for new counter
			}
		}
	case tickMsg:
		m.updateData()
		return m, tick()
	}
	return m, nil
}

func (m *model) updateData() {
	counterName := m.currentCounter
	if counterName == "" {
		counterName = "tx_bytes"
	}
	for _, adapter := range m.adapters {
		counter := readCounter(adapter, counterName)
		if m.data[adapter] == nil {
			m.data[adapter] = make([]uint64, 0, m.width)
		}
		m.data[adapter] = append(m.data[adapter], counter)
		if len(m.data[adapter]) > m.width {
			m.data[adapter] = m.data[adapter][1:]
		}
	}
}

func (m model) View() string {
	if len(m.adapters) == 0 {
		return "No EFA adapters found\nPress 'q' to quit"
	}

	var content string
	if m.statusView {
		content = m.renderStatus()
	} else if m.tableView {
		content = m.renderTable()
	} else if m.configView {
		content = m.renderConfig()
	} else {
		content = m.renderGrid()
	}
	footer := lipgloss.NewStyle().
		Foreground(lipgloss.Color("241")).
		Render("efatop v20250808 | [q]uit, [s]tatus, [m]onitor, [t]able, [c]onfig, ↑↓/jk scroll, Shift+↑↓/jk page scroll, 1-8 columns, Shift+1-4 rows")

	return fmt.Sprintf("%s\n%s", content, footer)
}

func (m model) renderGrid() string {
	cols := m.columns
	if cols == 0 {
		cols = 4
	}
	
	// Single column mode: use full screen
	if cols == 1 {
		rows := m.rows
		if rows == 0 {
			rows = 1
		}
		
		if rows == 1 {
			idx := m.scroll
			if idx >= len(m.adapters) {
				idx = len(m.adapters) - 1
			}
			if idx < 0 {
				idx = 0
			}
			return m.renderChart(m.adapters[idx], idx+1, m.height-1, m.width)
		}
		
		// Multiple rows in single column
		paneHeight := (m.height - 1) / rows
		if paneHeight < 8 {
			paneHeight = 8
		}
		
		startIdx := m.scroll
		var charts []string
		for i := 0; i < rows && startIdx+i < len(m.adapters); i++ {
			chart := m.renderChart(m.adapters[startIdx+i], startIdx+i+1, paneHeight, m.width)
			charts = append(charts, chart)
		}
		return strings.Join(charts, "\n")
	}
	
	rows := m.rows
	if rows == 0 {
		rows = 2
	}
	paneWidth := (m.width - 8) / cols
	paneHeight := (m.height - 6) / rows
	if paneHeight < 12 {
		paneHeight = 12
	}

	totalRows := (len(m.adapters) + cols - 1) / cols
	visibleRows := (m.height - 6) / paneHeight
	if visibleRows < 1 {
		visibleRows = 1
	}

	startRow := m.scroll
	if startRow > totalRows-visibleRows {
		startRow = totalRows - visibleRows
	}
	if startRow < 0 {
		startRow = 0
	}
	m.scroll = startRow

	var gridRows []string
	for row := startRow; row < startRow+visibleRows && row < totalRows; row++ {
		var panes []string
		for col := 0; col < cols; col++ {
			idx := row*cols + col
			if idx < len(m.adapters) {
				chart := m.renderChart(m.adapters[idx], idx+1, paneHeight-2, paneWidth-2)
				pane := lipgloss.NewStyle().
					Border(lipgloss.RoundedBorder()).
					Width(paneWidth).
					Height(paneHeight).
					Render(chart)
				panes = append(panes, pane)
			} else {
				empty := lipgloss.NewStyle().
					Border(lipgloss.RoundedBorder()).
					Width(paneWidth).
					Height(paneHeight).
					Render("")
				panes = append(panes, empty)
			}
		}
		gridRows = append(gridRows, lipgloss.JoinHorizontal(lipgloss.Top, panes...))
	}

	return lipgloss.JoinVertical(lipgloss.Left, gridRows...)
}

func (m model) renderChart(adapter string, index, height, width int) string {
	data := m.data[adapter]
	if len(data) < 2 {
		return fmt.Sprintf("%d. %s: Collecting data...", index, adapter)
	}

	// Calculate rates (bytes per second)
	rates := make([]float64, len(data)-1)
	for i := 1; i < len(data); i++ {
		if data[i] >= data[i-1] {
			rates[i-1] = float64(data[i] - data[i-1])
		}
	}

	if len(rates) == 0 {
		return fmt.Sprintf("%d. %s: No data", index, adapter)
	}

	// Find max for scaling
	var max float64
	for _, rate := range rates {
		if rate > max {
			max = rate
		}
	}
	if max == 0 {
		max = 1 // Prevent division by zero
	}

	// Get current rate and total bytes
	currentRate := uint64(0)
	if len(rates) > 0 {
		currentRate = uint64(rates[len(rates)-1])
	}
	totalBytes := uint64(0)
	if len(data) > 0 {
		totalBytes = data[len(data)-1]
	}

	// Create gonum plot
	p := plot.New()
	p.HideAxes()
	
	// Create line data
	pts := make(plotter.XYs, len(rates))
	for i, rate := range rates {
		pts[i].X = float64(i)
		pts[i].Y = rate
	}
	
	line, err := plotter.NewLine(pts)
	if err == nil {
		line.LineStyle.Width = vg.Points(0.5)
		line.LineStyle.Color = color.RGBA{R: 0, G: 100, B: 255, A: 255}
		p.Add(line)
	}
	
	// Convert to ASCII (simplified)
	counterName := m.currentCounter
	if counterName == "" {
		counterName = "tx_bytes"
	}
	title := fmt.Sprintf("EFA %d. %s | %s: %s/s | Max: %s/s | Total: %s", index, adapter, counterName, formatBytes(currentRate), formatBytes(uint64(max)), formatBytes(totalBytes))
	titleStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("39"))
	
	// Fallback ASCII chart
	chartWidth := width
	if chartWidth < 10 {
		chartWidth = 10
	}

	var lines []string
	lines = append(lines, titleStyle.Render(title))

	// Ensure minimum height for chart visibility
	if height < 8 {
		height = 8
	}
	
	// Create 2D grid for bar plotting - use more height for bars
	chartHeight := height - 3 // Reserve space for title and axis
	if chartHeight < 4 {
		chartHeight = 4
	}
	grid := make([][]bool, chartHeight)
	for i := range grid {
		grid[i] = make([]bool, chartWidth)
	}

	// Plot vertical bars - 1 character width, newest data on right
	dataPoints := len(rates)
	if dataPoints > chartWidth { dataPoints = chartWidth } // Limit to chart width
	
	for i := 0; i < dataPoints; i++ {
		dataIndex := len(rates) - dataPoints + i
		if dataIndex < 0 || dataIndex >= len(rates) {
			continue
		}
		
		// Calculate bar height with minimum visibility
		barHeight := int(rates[dataIndex] * float64(chartHeight) / max)
		if barHeight >= chartHeight { barHeight = chartHeight - 1 }
		if barHeight < 0 { barHeight = 0 }
		// Ensure at least 1 pixel for non-zero data
		if rates[dataIndex] > 0 && barHeight == 0 {
			barHeight = 1
		}
		
		// Position bars from right - newest data on right end
		gridX := chartWidth - dataPoints + i
		if gridX >= 0 && gridX < chartWidth {
			for j := 0; j <= barHeight; j++ {
				gridY := chartHeight-1-j
				if gridY >= 0 && gridY < len(grid) {
					grid[gridY][gridX] = true
				}
			}
		}
	}

	// Red to yellow to green gradient - 9 colors
	colors := []string{"196", "202", "208", "214", "220", "226", "190", "154", "46"}
	
	// Convert grid to colorful output
	for row := 0; row < chartHeight; row++ {
		line := ""
		// Gradient: bottom (low) = red, top (high) = green
		intensity := float64(chartHeight-1-row) / float64(chartHeight-1)
		colorIndex := int(intensity * float64(len(colors)-1))
		if colorIndex >= len(colors) {
			colorIndex = len(colors) - 1
		}
		rowColor := colors[colorIndex]
		
		for col := 0; col < chartWidth; col++ {
			if grid[row][col] {
				// Use gradient color for professional appearance
				coloredPoint := lipgloss.NewStyle().Foreground(lipgloss.Color(rowColor)).Render("█")
				line += coloredPoint
			} else {
				line += " "
			}
		}
		lines = append(lines, line)
	}

	// Add axis
	axis := lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(strings.Repeat("─", chartWidth))
	lines = append(lines, axis)

	return strings.Join(lines, "\n")
}

func (m model) renderStatus() string {
	header := lipgloss.NewStyle().Bold(true).Render("EFA Adapter Status")
	tableHeader := fmt.Sprintf("%-5s %-15s %-10s %-10s %-15s %-10s %-20s %-20s", "Index", "Adapter", "Rate", "State", "Phys State", "Device", "Node GUID", "GID")
	lines := []string{header, "", tableHeader, strings.Repeat("-", 120)}
	
	for i, adapter := range m.adapters {
		rate := readSysFile(fmt.Sprintf("/sys/class/infiniband/%s/ports/1/rate", adapter))
		state := readSysFile(fmt.Sprintf("/sys/class/infiniband/%s/ports/1/state", adapter))
		physState := readSysFile(fmt.Sprintf("/sys/class/infiniband/%s/ports/1/phys_state", adapter))
		device := readSysFile(fmt.Sprintf("/sys/class/infiniband/%s/device/device", adapter))
		nodeGuid := readSysFile(fmt.Sprintf("/sys/class/infiniband/%s/node_guid", adapter))
		gid := readSysFile(fmt.Sprintf("/sys/class/infiniband/%s/ports/1/gids/0", adapter))
		
		row := fmt.Sprintf("%-5d %-15s %-10s %-10s %-15s %-10s %-20s %-20s", i+1, adapter, rate, state, physState, device, nodeGuid, gid)
		lines = append(lines, row)
	}
	
	return strings.Join(lines, "\n")
}

func (m model) renderTable() string {
	counterName := m.currentCounter
	if counterName == "" {
		counterName = "tx_bytes"
	}
	header := lipgloss.NewStyle().Bold(true).Render(fmt.Sprintf("EFA Adapter Data Table - %s", counterName))
	tableHeader := fmt.Sprintf("%-5s %-15s %-15s %-15s", "Index", "Adapter", "Total", "Rate/s")
	lines := []string{header, "", tableHeader, strings.Repeat("-", 60)}
	
	for i, adapter := range m.adapters {
		data := m.data[adapter]
		if len(data) < 2 {
			row := fmt.Sprintf("%-5d %-15s %-15s %-15s", i+1, adapter, "N/A", "N/A")
			lines = append(lines, row)
			continue
		}
		
		totalBytes := data[len(data)-1]
		rate := uint64(0)
		if len(data) > 1 {
			prevBytes := data[len(data)-2]
			if totalBytes >= prevBytes {
				rate = totalBytes - prevBytes
			}
		}
		
		row := fmt.Sprintf("%-5d %-15s %-15s %-15s", i+1, adapter, formatBytes(totalBytes), formatBytes(rate))
		lines = append(lines, row)
	}
	
	return strings.Join(lines, "\n")
}

func (m *model) loadCounters() {
	if len(m.adapters) == 0 {
		return
	}
	countersPath := fmt.Sprintf("/sys/class/infiniband/%s/ports/1/hw_counters", m.adapters[0])
	entries, err := os.ReadDir(countersPath)
	if err != nil {
		return
	}
	m.counters = nil
	for _, entry := range entries {
		if entry.Type().IsRegular() {
			m.counters = append(m.counters, entry.Name())
		}
	}
	sort.Strings(m.counters)
}

func (m model) renderConfig() string {
	header := lipgloss.NewStyle().Bold(true).Render("Configure Counter")
	currentCounterText := m.currentCounter
	if currentCounterText == "" {
		currentCounterText = "tx_bytes (default)"
	}
	lines := []string{header, "", fmt.Sprintf("Current counter: %s", currentCounterText), "", "Available counters:"}
	
	for i, counter := range m.counters {
		if i == m.selectedCounter {
			selected := lipgloss.NewStyle().Background(lipgloss.Color("240")).Render(fmt.Sprintf("> %s", counter))
			lines = append(lines, selected)
		} else {
			lines = append(lines, fmt.Sprintf("  %s", counter))
		}
	}
	
	lines = append(lines, "", "Press Enter to select, ↑↓ to navigate")
	return strings.Join(lines, "\n")
}

func readSysFile(path string) string {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return "N/A"
	}
	return strings.TrimSpace(string(data))
}

func extractNumber(name string) int {
	re := regexp.MustCompile(`\d+`)
	match := re.FindString(name)
	if match == "" {
		return 0
	}
	num, _ := strconv.Atoi(match)
	return num
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func readCounter(adapter, counter string) uint64 {
	path := fmt.Sprintf("/sys/class/infiniband/%s/ports/1/hw_counters/%s", adapter, counter)
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return 0
	}
	
	value, err := strconv.ParseUint(strings.TrimSpace(string(data)), 10, 64)
	if err != nil {
		return 0
	}
	
	// Convert from 4-byte words to bytes
	return value * 4
}

func findEFAAdapters() []string {
	var adapters []string
	
	entries, err := os.ReadDir("/sys/class/infiniband")
	if err != nil {
		return adapters
	}
	
	for _, entry := range entries {
		if !entry.Type().IsRegular() {
			// Check if it's an EFA adapter by looking for the device type
			devicePath := filepath.Join("/sys/class/infiniband", entry.Name(), "device", "subsystem_device")
			if data, err := ioutil.ReadFile(devicePath); err == nil {
				// EFA devices typically have device ID 0xefa0 or 0xefa1 or 0xefa2
				deviceID := strings.TrimSpace(string(data))
				if strings.Contains(deviceID, "0xefa") {
					adapters = append(adapters, entry.Name())
				}
			}
		}
	}
	
	// If no EFA-specific adapters found, include all InfiniBand adapters
	if len(adapters) == 0 {
		for _, entry := range entries {
			if entry.IsDir() {
				adapters = append(adapters, entry.Name())
			}
		}
	}
	
	// Sort adapters by extracted number
	sort.Slice(adapters, func(i, j int) bool {
		return extractNumber(adapters[i]) < extractNumber(adapters[j])
	})
	
	return adapters
}

func formatBytes(bytes uint64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := uint64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

func main() {
	adapters := findEFAAdapters()
	
	m := model{
		adapters: adapters,
		data:     make(map[string][]uint64),
		columns:  4,
		rows:     2,
		currentCounter: "tx_bytes",
	}
	
	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error: %v", err)
		os.Exit(1)
	}
}