package ghcvm.runtime.apply;

import ghcvm.runtime.stg.StgClosure;
import ghcvm.runtime.stg.StgContext;
import ghcvm.runtime.stg.StackFrame;

public class ApPPVO extends StackFrame {
    public StgClosure p1;
    public StgClosure p2;
    public Object o;

    public ApPPVO(final StgClosure p1, final StgClosure p2, final Object o) {
        this.p1 = p1;
        this.p2 = p2;
        this.o = o;
    }

    @Override
    public void stackEnter(StgContext context) {
        StgClosure fun = context.R(1);
        fun.apply(context, p1, p2, null, o);
    }
}
