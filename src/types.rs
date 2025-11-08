use std::fmt;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Deserializer, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Activity {
    #[serde(rename = "type")]
    pub activity_type: ActivityType,
    pub id: Option<String>,
    pub timestamp: Option<DateTime<Utc>>,
    #[serde(rename = "serviceUrl")]
    pub service_url: Option<String>,
    #[serde(rename = "channelId")]
    pub channel_id: Option<String>,
    pub from: Option<ChannelAccount>,
    pub recipient: Option<ChannelAccount>,
    pub conversation: Option<ConversationAccount>,
    pub text: Option<String>,
    pub attachments: Option<Vec<Attachment>>,
    pub value: Option<Value>,
    #[serde(rename = "channelData")]
    pub channel_data: Option<Value>,
    #[serde(rename = "replyToId")]
    pub reply_to_id: Option<String>,
    pub name: Option<String>,
    #[serde(default)]
    pub entities: Vec<Value>,
}

impl Default for Activity {
    fn default() -> Self {
        Self {
            activity_type: ActivityType::Message,
            id: None,
            timestamp: None,
            service_url: None,
            channel_id: None,
            from: None,
            recipient: None,
            conversation: None,
            text: None,
            attachments: None,
            value: None,
            channel_data: None,
            reply_to_id: None,
            name: None,
            entities: Vec::new(),
        }
    }
}

impl Activity {
    pub fn activity_id(&self) -> Option<&str> {
        self.id.as_deref()
    }

    pub fn tenant_trace_id(&self) -> Option<String> {
        if let Some(channel_data) = &self.channel_data {
            if let Some(trace_id) = channel_data.get("traceId").and_then(|v| v.as_str()) {
                return Some(trace_id.to_string());
            }
            if let Some(trace_id) = channel_data.get("trace_id").and_then(|v| v.as_str()) {
                return Some(trace_id.to_string());
            }
        }

        self.conversation.as_ref().and_then(|conv| conv.id.clone())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ChannelAccount {
    pub id: Option<String>,
    pub name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConversationAccount {
    pub id: Option<String>,
    pub name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Attachment {
    #[serde(rename = "contentType")]
    pub content_type: String,
    pub content: Value,
    pub name: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub enum ActivityType {
    #[default]
    Message,
    Event,
    Invoke,
    Typing,
    Unknown(String),
}

impl ActivityType {
    pub fn as_str(&self) -> &str {
        match self {
            ActivityType::Message => "message",
            ActivityType::Event => "event",
            ActivityType::Invoke => "invoke",
            ActivityType::Typing => "typing",
            ActivityType::Unknown(s) => s.as_str(),
        }
    }
}

impl fmt::Display for ActivityType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

impl<'de> Deserialize<'de> for ActivityType {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        Ok(match value.as_str() {
            "message" => ActivityType::Message,
            "event" => ActivityType::Event,
            "invoke" => ActivityType::Invoke,
            "typing" => ActivityType::Typing,
            other => ActivityType::Unknown(other.to_string()),
        })
    }
}

impl Serialize for ActivityType {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(self.as_str())
    }
}
