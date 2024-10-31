# MiCASA

Más-Informada CASA (MiCASA).

## Recipe (so far, ugh)
1. Go to `src/CASA`
1A. Run CASA in Matlab/Octave
1B. Run convertOutput 
2. Go to fluxape and run `lofi2.make_sink`
2A. If that complains about anything, or the first time, run
`lofi2.make_sink_prep1` and `lofi2.make_sink_prep2`.
3. Go to root and run `./bin/postretro.sh process`
4. Go to fluxape and run `lofi2.make_3hrly_land`
