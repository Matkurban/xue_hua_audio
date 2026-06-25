#[cfg(target_os = "android")]
mod imp {
    use jni::JNIEnv;
    use jni::objects::{GlobalRef, JClass, JObject};
    use std::ffi::c_void;
    use std::sync::{Once, OnceLock};

    static CTX: OnceLock<GlobalRef> = OnceLock::new();
    static INIT: Once = Once::new();

    #[no_mangle]
    pub extern "system" fn Java_com_flutter_1rust_1bridge_xue_1hua_1audio_1player_XueHuaAudioPlugin_init_1android(
        env: JNIEnv,
        _class: JClass,
        ctx: JObject,
    ) {
        INIT.call_once(|| {
            let global_ref = env
                .new_global_ref(&ctx)
                .expect("failed to create global Android context reference");
            let vm = env.get_java_vm().expect("failed to get JavaVM");
            unsafe {
                ndk_context::initialize_android_context(
                    vm.get_java_vm_pointer() as *mut c_void,
                    global_ref.as_obj().as_raw() as *mut c_void,
                );
            }
            CTX.get_or_init(|| global_ref);
        });
    }
}
