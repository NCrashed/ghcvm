package ghcvm.runtime.exception;

import ghcvm.runtime.stg.StgTSO;
import ghcvm.runtime.stg.StackFrame;
import ghcvm.runtime.stg.StgContext;
import static ghcvm.runtime.stg.StgTSO.TSO_BLOCKEX;
import static ghcvm.runtime.stg.StgTSO.TSO_INTERRUPTIBLE;

public class MaskAsyncExceptionsFrame extends StackFrame {

    @Override
    public void stackEnter(StgContext context) {
        StgTSO tso = context.currentTSO;
        tso.addFlags(TSO_BLOCKEX | TSO_INTERRUPTIBLE);
    }
}
