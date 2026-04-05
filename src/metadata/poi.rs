pub fn category_from_tags(tags: &HashMap<String, String>) -> String {
    if let Some(val) = tags.get("railway") {
        if val == "station" { return "station".to_string(); }
    }
    if let Some(val) = tags.get("tourism") {
        if val == "attraction" { return "attraction".to_string(); }
    }
    if let Some(val) = tags.get("amenity") {
        match val.as_str() {
            "school" => return "school".to_string(),
            "hospital" => return "hospital".to_string(),
            "townhall" => return "townhall".to_string(),
            _ => {}
        }
    }
    if let Some(val) = tags.get("leisure") {
        match val.as_str() {
            "park" => return "park".to_string(),
            "stadium" => return "stadium".to_string(),
            _ => {}
        }
    }
    if let Some(val) = tags.get("place") {
        if val == "square" { return "square".to_string(); }
    }
    if let Some(val) = tags.get("historic") {
        if val == "memorial" || val == "monument" { return "memorial".to_string(); }
    }
    if tags.get("memorial").is_some() {
        return "memorial".to_string();
    }
    "unknown".to_string()
}

pub fn name_fallback(tags: &HashMap<String, String>, category: &str, osm_id: i64) -> String {
    if let Some(name) = tags.get("name") {
        return name.clone();
    }
    if let Some(name) = tags.get("official_name") {
        return name.clone();
    }
    if let Some(name) = tags.get("short_name") {
        return name.clone();
    }
    if let Some(desc) = tags.get("description") {
        return desc.clone();
    }
    format!("{} {}", capitalize_first(category), osm_id)
}

fn capitalize_first(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
    }
}
use serde::Serialize;
use std::collections::HashMap;

#[derive(Debug, Serialize, Clone)]
pub struct Poi {
    pub name: String,
    pub osm_id: i64,
    pub category: String,
    pub geometry_type: String,
    pub lat: Option<f64>,
    pub lon: Option<f64>,
    pub x: Option<i32>,
    pub z: Option<i32>,
    pub position_valid: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub position_error: Option<String>,
    pub tags: HashMap<String, String>,
}
