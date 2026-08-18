//! Custom [`FLUTTER_RUST_BRIDGE_HANDLER`] — Android uses `current_thread` Tokio to avoid
//! multi-thread runtime pthread_key exhaustion on SDK-heavy apps.

#[cfg(target_os = "android")]
use threadpool::ThreadPool;

#[cfg(not(target_os = "android"))]
use flutter_rust_bridge::DefaultHandler;
#[cfg(not(target_os = "android"))]
use flutter_rust_bridge::for_generated::SimpleThreadPool;
use flutter_rust_bridge::for_generated::{FLUTTER_RUST_BRIDGE_RUNTIME_VERSION, lazy_static};
#[cfg(target_os = "android")]
use flutter_rust_bridge::for_generated::{
    NoOpErrorListener, SimpleExecutor, SimpleHandler, SimpleThreadPool,
};

use crate::frb_generated::FLUTTER_RUST_BRIDGE_CODEGEN_VERSION;

#[cfg(target_os = "android")]
mod current_thread_runtime {
    use std::future::Future;
    use std::panic::AssertUnwindSafe;

    use flutter_rust_bridge::rust_async::BaseAsyncRuntime;
    use tokio::task::JoinHandle;

    #[derive(Debug)]
    pub struct CurrentThreadAsyncRuntime(pub AssertUnwindSafe<tokio::runtime::Runtime>);

    impl Default for CurrentThreadAsyncRuntime {
        fn default() -> Self {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("FRB Android current_thread tokio runtime");
            Self(AssertUnwindSafe(rt))
        }
    }

    impl BaseAsyncRuntime for CurrentThreadAsyncRuntime {
        fn spawn<F>(&self, future: F) -> JoinHandle<F::Output>
        where
            F: Future + Send + 'static,
            F::Output: Send + 'static,
        {
            self.0.spawn(future)
        }
    }
}

#[cfg(target_os = "android")]
type FrbHandler = SimpleHandler<
    SimpleExecutor<
        NoOpErrorListener,
        SimpleThreadPool,
        current_thread_runtime::CurrentThreadAsyncRuntime,
    >,
    NoOpErrorListener,
>;

#[cfg(not(target_os = "android"))]
type FrbHandler = DefaultHandler<SimpleThreadPool>;

fn build_handler() -> FrbHandler {
    assert_eq!(
        FLUTTER_RUST_BRIDGE_CODEGEN_VERSION, FLUTTER_RUST_BRIDGE_RUNTIME_VERSION,
        "Please ensure flutter_rust_bridge's codegen ({}) and runtime ({}) versions are the same",
        FLUTTER_RUST_BRIDGE_CODEGEN_VERSION, FLUTTER_RUST_BRIDGE_RUNTIME_VERSION,
    );

    #[cfg(target_os = "android")]
    {
        use current_thread_runtime::CurrentThreadAsyncRuntime;

        SimpleHandler::new(
            SimpleExecutor::new(
                NoOpErrorListener,
                SimpleThreadPool(ThreadPool::new(1)),
                CurrentThreadAsyncRuntime::default(),
            ),
            NoOpErrorListener,
        )
    }

    #[cfg(not(target_os = "android"))]
    {
        DefaultHandler::new_simple(Default::default())
    }
}

lazy_static! {
    /// Process-wide FRB handler; Android uses a single-thread Tokio runtime.
    pub static ref FLUTTER_RUST_BRIDGE_HANDLER: FrbHandler = build_handler();
}
