use std::fmt;

#[derive(Debug, Clone)]
pub struct BridgeError {
    pub code: &'static str,
    pub message: String,
}

impl BridgeError {
    pub fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }

    pub fn manager_unavailable(msg: impl Into<String>) -> Self {
        Self::new("managerUnavailable", msg)
    }

    pub fn dbus_failed(msg: impl Into<String>) -> Self {
        Self::new("dbusCallFailed", msg)
    }

    pub fn start_stream_failed(msg: impl Into<String>) -> Self {
        Self::new("startStreamFailed", msg)
    }

    pub fn stop_stream_failed(msg: impl Into<String>) -> Self {
        Self::new("stopStreamFailed", msg)
    }

    pub fn invalid_args(msg: impl Into<String>) -> Self {
        Self::new("invalidArguments", msg)
    }

    pub fn unit_failed(msg: impl Into<String>) -> Self {
        Self::new("unitFailed", msg)
    }
}

impl fmt::Display for BridgeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{}]: {}", self.code, self.message)
    }
}

impl std::error::Error for BridgeError {}

impl From<zbus::Error> for BridgeError {
    fn from(e: zbus::Error) -> Self {
        BridgeError::dbus_failed(e.to_string())
    }
}

