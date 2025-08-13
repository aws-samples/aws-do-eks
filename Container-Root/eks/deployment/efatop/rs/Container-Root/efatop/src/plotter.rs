use anyhow::Result;
use std::fs::File;
use std::io::Write;

pub fn create_svg_chart(rates: &[(String, f64, f64)]) -> Result<()> {
    let width = 800;
    let height = 600;
    let margin = 50;
    let chart_width = width - 2 * margin;
    let chart_height = height - 2 * margin;
    
    let max_rate = rates
        .iter()
        .map(|(_, tx, rx)| tx.max(*rx))
        .fold(0.0f64, f64::max)
        .max(1.0);
    
    let mut svg = String::new();
    svg.push_str(&format!(r#"<svg width="{}" height="{}" xmlns="http://www.w3.org/2000/svg">"#, width, height));
    svg.push_str("\n");
    
    // Background
    svg.push_str(&format!(r#"<rect width="{}" height="{}" fill="white" stroke="black"/>"#, width, height));
    svg.push_str("\n");
    
    // Title
    svg.push_str(&format!(r#"<text x="{}" y="30" text-anchor="middle" font-size="20" font-family="Arial">EFA Network Traffic</text>"#, width / 2));
    svg.push_str("\n");
    
    // Y-axis label
    svg.push_str(&format!(r#"<text x="20" y="{}" text-anchor="middle" font-size="12" font-family="Arial" transform="rotate(-90 20 {})">Rate (MB/s)</text>"#, height / 2, height / 2));
    svg.push_str("\n");
    
    // Chart area border
    svg.push_str(&format!(r#"<rect x="{}" y="{}" width="{}" height="{}" fill="none" stroke="black"/>"#, margin, margin, chart_width, chart_height));
    svg.push_str("\n");
    
    if !rates.is_empty() {
        let bar_width = chart_width / (rates.len() * 2) as i32;
        
        for (i, (name, tx_rate, rx_rate)) in rates.iter().enumerate() {
            let x_base = margin + (i * 2 * bar_width as usize) as i32;
            
            // TX bar (blue)
            let tx_height = (tx_rate / max_rate * chart_height as f64) as i32;
            let tx_y = margin + chart_height - tx_height;
            svg.push_str(&format!(r#"<rect x="{}" y="{}" width="{}" height="{}" fill="blue" opacity="0.7"/>"#, 
                x_base, tx_y, bar_width, tx_height));
            svg.push_str("\n");
            
            // RX bar (red)
            let rx_height = (rx_rate / max_rate * chart_height as f64) as i32;
            let rx_y = margin + chart_height - rx_height;
            svg.push_str(&format!(r#"<rect x="{}" y="{}" width="{}" height="{}" fill="red" opacity="0.7"/>"#, 
                x_base + bar_width, rx_y, bar_width, rx_height));
            svg.push_str("\n");
            
            // Adapter name
            svg.push_str(&format!(r#"<text x="{}" y="{}" text-anchor="middle" font-size="10" font-family="Arial">{}</text>"#, 
                x_base + bar_width, height - 10, name));
            svg.push_str("\n");
            
            // Values
            svg.push_str(&format!(r#"<text x="{}" y="{}" text-anchor="middle" font-size="8" font-family="Arial">TX: {:.1}</text>"#, 
                x_base + bar_width / 2, tx_y - 5, tx_rate));
            svg.push_str("\n");
            svg.push_str(&format!(r#"<text x="{}" y="{}" text-anchor="middle" font-size="8" font-family="Arial">RX: {:.1}</text>"#, 
                x_base + bar_width + bar_width / 2, rx_y - 5, rx_rate));
            svg.push_str("\n");
        }
    }
    
    // Legend
    svg.push_str(&format!(r#"<rect x="{}" y="10" width="15" height="15" fill="blue" opacity="0.7"/>"#, width - 100));
    svg.push_str(&format!(r#"<text x="{}" y="22" font-size="12" font-family="Arial">TX</text>"#, width - 80));
    svg.push_str(&format!(r#"<rect x="{}" y="10" width="15" height="15" fill="red" opacity="0.7"/>"#, width - 50));
    svg.push_str(&format!(r#"<text x="{}" y="22" font-size="12" font-family="Arial">RX</text>"#, width - 30));
    svg.push_str("\n");
    
    svg.push_str("</svg>");
    
    let mut file = File::create("efa_traffic.svg")?;
    file.write_all(svg.as_bytes())?;
    
    println!("SVG chart saved to efa_traffic.svg");
    Ok(())
}