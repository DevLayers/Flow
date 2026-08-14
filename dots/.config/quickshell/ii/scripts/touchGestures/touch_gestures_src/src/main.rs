mod devices;
mod protocol;

use devices::DeviceManager;
use protocol::{emit_event, OutEvent};

fn main() {
    emit_event(&OutEvent::Ready { version: 1 });

    let manager = DeviceManager::new();
    manager.start_discovery();

    loop {
        std::thread::park();
    }
}
