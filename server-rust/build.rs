use std::io::Result;
fn main() -> Result<()> {
    prost_build::compile_protos(&["../protos/auction.proto"], &["../protos/"])?;
    Ok(())
}
