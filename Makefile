JL          = ~/.julia/julia
OPTS        = "--machine-file=$$PBS_NODEFILE"
BASE        = functions.jl setup.jl ann.jl
CORE        = ml_core.jl
OBJS        = main.jl
CALC        = calculation.jl
VIEW        = view.jl

main: $(BASE) $(CORE) $(OBJS) $(CALC)
	$(JL) $(OPTS) $(OBJS)
	$(JL) $(CALC)

calc: $(BASE) $(CORE) $(CALC)
	$(JL) $(CALC)

test: $(BASE) $(CORE) $(OBJS) $(VIEW)
	$(JL) $(OPTS) $(OBJS)
	$(JL) $(VIEW)

clean:
	-rm -f *.txt *.png *.dat nohup.out
	-rm -rf data error
