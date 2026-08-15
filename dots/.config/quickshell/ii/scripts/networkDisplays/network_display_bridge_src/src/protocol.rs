use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum NetworkDisplayProtocol {
    Unknown,
    MiracastP2p,
    MiracastMice,
    Chromecast,
}

impl NetworkDisplayProtocol {
    pub fn from_u32(val: u32) -> Self {
        match val {
            1 => NetworkDisplayProtocol::MiracastP2p,
            2 => NetworkDisplayProtocol::MiracastMice,
            3 => NetworkDisplayProtocol::Chromecast,
            _ => NetworkDisplayProtocol::Unknown,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            NetworkDisplayProtocol::MiracastP2p => "miracastP2p",
            NetworkDisplayProtocol::MiracastMice => "miracastMice",
            NetworkDisplayProtocol::Chromecast => "chromecast",
            NetworkDisplayProtocol::Unknown => "unknown",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DisplayItem {
    pub uuid: String,
    pub name: String,
    pub priority: u32,
    pub state: u32,
    pub protocol: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub address: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub port: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum ManagerEvent {
    BridgeReady {
        version: u32,
    },
    ManagerUnavailable,
    ManagerAvailable {
        owner: String,
    },
    DisplaysSnapshot {
        displays: Vec<DisplayItem>,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum UnitWatchEvent {
    UnitState {
        unit: String,
        active_state: String,
        sub_state: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListResponse {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub displays: Option<Vec<DisplayItem>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StartResponse {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub uuid: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stream_unit: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StopResponse {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stream_unit: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DiagnoseReport {
    pub ok: bool,
    pub bridge: BridgeDiag,
    pub backend: BackendDiag,
    pub portal: PortalDiag,
    pub pipewire: PipewireDiag,
    pub network_manager: NetworkManagerDiag,
    pub codecs: CodecsDiag,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BridgeDiag {
    pub ok: bool,
    pub version: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BackendDiag {
    pub daemon_binary: bool,
    pub daemon_path: Option<String>,
    pub manager_bus: bool,
    pub manager_owner: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PortalDiag {
    pub desktop_portal: bool,
    pub screen_cast: bool,
    pub hyprland_backend: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PipewireDiag {
    pub available: bool,
    pub socket_exists: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NetworkManagerDiag {
    pub available: bool,
    pub wifi_device: bool,
    pub p2p_device: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CodecsDiag {
    pub h264: Vec<String>,
    pub aac: Vec<String>,
}
