use std::fs::File;
use std::io::Result;
use std::path::Path;
use serde::Serialize;
use crate::metadata::poi::Poi;

#[derive(Serialize)]
pub struct Metadata {
    pub world: String,
    pub pois: Vec<Poi>,
}

pub fn export_metadata<P: AsRef<Path>>(world_name: &str, pois: &[Poi], world_folder: P) -> Result<()> {
    let metadata = Metadata {
        world: world_name.to_string(),
        pois: pois.to_vec(),
    };
    let path = world_folder.as_ref().join("metadata.json");
    let file = File::create(path)?;
    serde_json::to_writer_pretty(file, &metadata)?;
    Ok(())
}
