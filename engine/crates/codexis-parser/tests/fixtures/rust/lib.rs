use crate::model::Record;

pub mod storage {
    pub struct Store {
        pub value: u32,
    }

    pub enum State {
        Ready,
        Busy,
    }

    pub trait Readable {
        fn read(&self) -> u32;
    }

    impl Store {
        pub fn get(&self) -> u32 {
            self.value
        }
    }
}

fn helper(_: Record) {}
