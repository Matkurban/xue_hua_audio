#[cfg(target_os = "android")]
mod imp {
    use jni::{
        errors::Result as JniResult,
        objects::{Global, JClass, JObject},
        refs::Reference as _,
        EnvUnowned,
    };
    use std::ffi::c_void;
    use std::sync::OnceLock;

    /// Keeps the application Context alive after passing its raw pointer to ndk-context.
    static CONTEXT_HOLDER: OnceLock<Global<JObject<'static>>> = OnceLock::new();

    #[unsafe(no_mangle)]
    pub extern "system" fn Java_com_flutter_1rust_1bridge_xue_1hua_1audio_XueHuaAudioPlugin_initAndroid<
        'local,
    >(
        mut unowned_env: EnvUnowned<'local>,
        _class: JClass<'local>,
        context: JObject<'local>,
    ) {
        let _ = unowned_env.with_env(|env| -> JniResult<()> {
            if CONTEXT_HOLDER.get().is_some() {
                return Ok(());
            }
            let global_ref = env.new_global_ref(context)?;
            let vm = env.get_java_vm()?;
            let vm_ptr = vm.get_raw() as *mut c_void;
            let ctx_ptr = global_ref.as_obj().as_raw() as *mut c_void;
            unsafe {
                ndk_context::initialize_android_context(vm_ptr, ctx_ptr);
            }
            let _ = CONTEXT_HOLDER.set(global_ref);
            Ok(())
        });
    }
}
