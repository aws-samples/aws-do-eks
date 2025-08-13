# EFATop-RS - EFA Network Traffic Visualizer

A Rust-based TUI tool for visualizing Elastic Fabric Adapter (EFA) network traffic using ratatui with real-time line graphs.

## Features

- Auto-discovery of EFA adapters from `/sys/class/infiniband`
- Real-time monitoring of TX/RX traffic rates
- Interactive TUI with line graphs for each adapter
- Grid layout showing multiple adapters simultaneously
- Historical data tracking (last 100 data points)

## Installation

```bash
cd efatop-rs
cargo build --release
```

## Usage

```bash
sudo ./target/release/efatop-rs
```

Note: Root privileges may be required to read hardware counters from `/sys/class/infiniband`.

## Output

The application displays:
1. Real-time line graphs for each EFA adapter in a grid layout
2. TX (blue) and RX (red) traffic rates over time
3. Auto-scaling Y-axis based on maximum observed rates

## Controls

- `q`: Quit the application

## Requirements

- Rust 1.70+
- EFA adapters with InfiniBand interface
- Access to `/sys/class/infiniband` directory

## Dependencies

- `ratatui`: Terminal user interface library
- `crossterm`: Cross-platform terminal manipulation
- `tokio`: Async runtime
- `serde`: Serialization support
- `anyhow`: Error handling
- `chrono`: Timestamp handling