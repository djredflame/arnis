
use crate::osm_parser::ProcessedElement;
use crate::coordinate_system::transformation::CoordTransformer;

#[derive(Debug)]
pub struct RepresentativePoint {
    pub lat: Option<f64>,
    pub lon: Option<f64>,
    pub x: Option<i32>,
    pub z: Option<i32>,
    pub valid: bool,
    pub error: Option<String>,
}

impl RepresentativePoint {
    pub fn invalid(error: &str) -> Self {
        Self {
            lat: None,
            lon: None,
            x: None,
            z: None,
            valid: false,
            error: Some(error.to_string()),
        }
    }
    pub fn valid(lat: f64, lon: f64, x: i32, z: i32) -> Self {
        Self {
            lat: Some(lat),
            lon: Some(lon),
            x: Some(x),
            z: Some(z),
            valid: true,
            error: None,
        }
    }
}

/// Compute a representative point for a ProcessedElement.
/// Returns lat/lon and x/z if possible, else error.
pub fn compute_representative_point(
    element: &ProcessedElement,
    transformer: Option<&CoordTransformer>,
) -> RepresentativePoint {
    match element {
        ProcessedElement::Node(node) => {
            if let (Some(lat), Some(lon)) = (node.lat, node.lon) {
                if let Some(trans) = transformer {
                    let llpoint = crate::coordinate_system::geographic::LLPoint::new(lat, lon);
                    if let Ok(llpoint) = llpoint {
                        let xz = trans.transform_point(llpoint);
                        return RepresentativePoint::valid(lat, lon, xz.x, xz.z);
                    } else {
                        return RepresentativePoint::invalid("invalid_lat_lon");
                    }
                } else {
                    return RepresentativePoint::invalid("missing_transformer");
                }
            }
            RepresentativePoint::invalid("missing_node_coordinates")
        }
        ProcessedElement::Way(way) => {
            if way.nodes.is_empty() {
                return RepresentativePoint::invalid("way_no_nodes");
            }
            // Compute centroid in lat/lon if available, else bbox center
            let (sum_lat, sum_lon, count, _min_lat, _max_lat, _min_lon, _max_lon) = way.nodes.iter().fold(
                (0.0, 0.0, 0, f64::MAX, f64::MIN, f64::MAX, f64::MIN),
                |(slat, slon, c, minlat, maxlat, minlon, maxlon), n| {
                    let (lat, lon) = match (n.lat, n.lon) {
                        (Some(lat), Some(lon)) => (lat, lon),
                        _ => return (slat, slon, c, minlat, maxlat, minlon, maxlon),
                    };
                    (
                        slat + lat,
                        slon + lon,
                        c + 1,
                        minlat.min(lat),
                        maxlat.max(lat),
                        minlon.min(lon),
                        maxlon.max(lon),
                    )
                },
            );
            if count > 0 {
                let centroid_lat = sum_lat / count as f64;
                let centroid_lon = sum_lon / count as f64;
                if let Some(trans) = transformer {
                    let llpoint = crate::coordinate_system::geographic::LLPoint::new(centroid_lat, centroid_lon);
                    if let Ok(llpoint) = llpoint {
                        let xz = trans.transform_point(llpoint);
                        return RepresentativePoint::valid(centroid_lat, centroid_lon, xz.x, xz.z);
                    } else {
                        return RepresentativePoint::invalid("invalid_lat_lon_centroid");
                    }
                } else {
                    return RepresentativePoint::invalid("missing_transformer");
                }
            }
            RepresentativePoint::invalid("way_nodes_missing_lat_lon")
        }
        ProcessedElement::Relation(rel) => {
            // Use all outer member nodes for centroid/bbox
            let mut latlons = Vec::new();
            for member in &rel.members {
                for node in &member.way.nodes {
                    if let (Some(lat), Some(lon)) = (node.lat, node.lon) {
                        latlons.push((lat, lon));
                    }
                }
            }
            if !latlons.is_empty() {
                let (sum_lat, sum_lon, count, _min_lat, _max_lat, _min_lon, _max_lon) = latlons.iter().fold(
                    (0.0, 0.0, 0, f64::MAX, f64::MIN, f64::MAX, f64::MIN),
                    |(slat, slon, c, minlat, maxlat, minlon, maxlon), (lat, lon)| {
                        (
                            slat + lat,
                            slon + lon,
                            c + 1,
                            minlat.min(*lat),
                            maxlat.max(*lat),
                            minlon.min(*lon),
                            maxlon.max(*lon),
                        )
                    },
                );
                if count > 0 {
                    let centroid_lat = sum_lat / count as f64;
                    let centroid_lon = sum_lon / count as f64;
                    if let Some(trans) = transformer {
                        let llpoint = crate::coordinate_system::geographic::LLPoint::new(centroid_lat, centroid_lon);
                        if let Ok(llpoint) = llpoint {
                            let xz = trans.transform_point(llpoint);
                            return RepresentativePoint::valid(centroid_lat, centroid_lon, xz.x, xz.z);
                        } else {
                            return RepresentativePoint::invalid("invalid_lat_lon_centroid");
                        }
                    } else {
                        return RepresentativePoint::invalid("missing_transformer");
                    }
                }
            }
            RepresentativePoint::invalid("no_representative_point")
        }
    }
}
