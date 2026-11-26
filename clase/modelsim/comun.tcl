# Funciones comunes de los scripts de ModelSim (las carga compilar.do)

quietly set ROOT [file normalize ../..]

# plusargs de cada condicion de memoria (las mismas que sim/run_core_tests.py)
quietly array set COND {
    lat0        {+LAT_MAX=0}
    lat3        {+LAT_MAX=3 +SEED=11}
    lat2+halt   {+LAT_MAX=2 +EN_RAND +SEED=5}
    m10k        {+MEM_RTL}
    m10k+halt   {+MEM_RTL +EN_RAND +SEED=7}
}

# Lee una traza (la del testbench o la esperada) -> {commits stores tohost}
proc leer_traza {archivo} {
    set c {}; set s {}; set th ""
    set fh [open $archivo r]
    while {[gets $fh l] >= 0} {
        set p [regexp -all -inline {\S+} $l]
        switch -- [lindex $p 0] {
            C      { lappend c [join $p " "] }
            S      { lappend s [join $p " "] }
            TOHOST { set th [lindex $p 1] }
        }
    }
    close $fh
    return [list $c $s $th]
}

# Compara la traza del RTL con la del modelo de referencia. Devuelve "" si coinciden.
proc comparar {traza esperado} {
    if {![file exists $traza]} { return "no se genero la traza" }
    lassign [leer_traza $traza] c1 s1 th
    lassign [leer_traza $esperado] c2 s2 -
    set n [expr {min([llength $c1], [llength $c2])}]
    for {set i 0} {$i < $n} {incr i} {
        if {[lindex $c1 $i] ne [lindex $c2 $i]} {
            return "instruccion #$i: rtl {[lindex $c1 $i]}  esperado {[lindex $c2 $i]}"
        }
    }
    if {[llength $c1] != [llength $c2]} {
        return "retiro [llength $c1] instrucciones, esperadas [llength $c2]"
    }
    if {$s1 ne $s2} { return "los stores no coinciden" }
    return ""
}

# PC del store a TOHOST (ultima instruccion retirada); lo necesita la simulacion gate-level
proc pc_tohost {esperado} {
    lassign [leer_traza $esperado] c - -
    return [lindex [lindex $c end] 1]
}

proc plusargs_cond {c} {
    global COND
    if {![info exists COND($c)]} {
        error "condicion '$c' desconocida; validas: [lsort [array names COND]]"
    }
    return $COND($c)
}

# Ejecuta un bloque solo si ModelSim tiene interfaz grafica (no en vsim -c)
proc gui {script} {
    if {![batch_mode]} { uplevel 1 $script }
}
