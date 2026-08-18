fn main() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    match target_os.as_str() {
        "macos" => {
            println!("cargo:rustc-link-lib=framework=AudioToolbox");
            println!("cargo:rustc-link-lib=framework=CoreAudio");
            println!("cargo:rustc-link-lib=framework=AudioUnit");
            println!("cargo:rustc-link-lib=framework=CoreFoundation");
        }
        "ios" => {
            println!("cargo:rustc-link-lib=framework=AudioToolbox");
            println!("cargo:rustc-link-lib=framework=CoreAudio");
            println!("cargo:rustc-link-lib=framework=AVFoundation");
            println!("cargo:rustc-link-lib=framework=CoreFoundation");
        }
        "linux" => {
            println!("cargo:rustc-link-lib=asound");
            println!("cargo:rustc-link-lib=pthread");
            println!("cargo:rustc-link-lib=dl");
            println!("cargo:rustc-link-lib=m");
        }
        "android" => {
            println!("cargo:rustc-link-lib=OpenSLES");
            println!("cargo:rustc-link-lib=dl");
        }
        "windows" => {
            println!("cargo:rustc-link-lib=ole32");
            println!("cargo:rustc-link-lib=winmm");
            println!("cargo:rustc-link-lib=propsys");
            println!("cargo:rustc-link-lib=uuid");
        }
        _ => {}
    }
}
