clearscreen.
set ship:control:pilotmainthrottle to 0.
wait 5.

// Coordenadas de aterrizaje
set baseLat to -0.09694.
set baseLng to -74.55750.
set tower to latlng(baseLat, baseLng).
set radarOffset to 60.
set landingsite to latlng(baseLat, baseLng).

// Marcar coordenada de aterrizaje en el mapa con flecha verde
addons:tr:settarget(landingsite).


// Variables físicas
lock trueRadar to alt:radar - radarOffset.                  
lock g to constant:g * body:mass / body:radius^2.           
lock maxDecel to (ship:availablethrust / ship:mass) - g.    
lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).     
lock idealThrottle to stopDist / trueRadar.                 
lock impactTime to trueRadar / abs(ship:verticalspeed). 
lock aoa to 30. 
lock errorScaling to 1.                                              

// Funciones de cálculo
function getImpact {
    if addons:tr:hasimpact { return addons:tr:impactpos. }           
    return ship:geoposition.
}

function lngError { return getImpact():lng - landingsite:lng. }
function latError { return getImpact():lat - landingsite:lat. }
function errorVector { return getImpact():position - landingSite:position. }

function getSteering {            
    local errorVector is errorVector().
    local velVector is -ship:velocity:surface.
    local result is velVector + errorVector*errorScaling.
    if vang(result, velVector) > aoa {
        set result to velVector:normalized + tan(aoa)*errorVector:normalized.
    }
    return lookdirup(result, facing:topvector).
}
function towerApproachSteering {
    local vertical is up:vector.
    local errorVec is landingsite:position - ship:position.
    // eliminar componente vertical
    set errorVec to errorVec - vdot(errorVec, vertical) * vertical.

    // ganancia lateral proporcional a la altitud
    local gain is min(1, (1000 - alt:radar) / 1000). // 0 a 1 entre 2 km y suelo

    // vector combinado: vertical + corrección lateral
    local steerVec is vertical + errorVec:normalized * gain * 0.5.

    return lookdirup(steerVec:normalized, facing:topvector).
}
function getSteering2 {
    // Vector de error hacia el sitio de aterrizaje
    local errorVec is errorVector().
    
    // Vector de velocidad retrogrado (para frenar la caída)
    local velVec is -ship:velocity:surface.
    
    // Combinación de retrogrado + corrección lateral
    // El factor 0.1 evita que el empuje mate toda la horizontal
    local result is velVec + errorVec * errorScaling * 0.1.
    
    // Limitar el ángulo de ataque (AoA) para evitar desviaciones bruscas
    if vang(result, velVec) > aoa {
        set result to velVec:normalized + tan(aoa) * errorVec:normalized.
    }
    
    // Orientar la nave con ese vector combinado
    return lookdirup(result:normalized, facing:topvector).
}





// --- Aterrizaje ---
function doland{
    toggle ag3.
     print "landing started".
    lock steering to getSteering().
  lock aoa to 30.
  
  
  when alt:radar < 12000 then {
    rcs off.
    lock aoa to 15.
  }

  

 when impactTime < 3.5 then {gear on.} 
 wait until  trueRadar < 10000. {
 lock throttle to idealThrottle.
	 
     lock aoa to 15.	
     lock steering to getSteering().

 when alt:radar <= 4000 then {
        lock steering to up.
        print "codigo2".
    }

 when alt:radar <= 2000 then {
        lock steering to towerApproachSteering().
        print "codigo2".
    }

     
     
 when alt:radar <=200 then { 
 lock steering to up + R(0,0,270).
 }
 WAIT UNTIL altitude <= 85.
 doshutdown().
}
}


// --- Corrección aerodinámica entre 30 km y 20 km ---

function doaerocorrection {
    print "Corrección aerodinámica intensiva iniciada".

    // Declarar AoA como variable modificable
    set aoa to 35.

    // Activar corrección desde 80 km hasta 20 km
    wait until altitude < 80000.

    until altitude < 20000 {
        // Recalcular error y velocidad
        local errorVec is landingsite:position - getImpact():position.
        local velVec is -ship:velocity:surface.

        // Vector de corrección más agresivo
        local steerVec is velVec + errorVec:normalized * 0.25.

        // Limitar AoA para evitar pérdida de control
        if vang(steerVec, velVec) > aoa {
            set steerVec to velVec:normalized + tan(aoa) * errorVec:normalized.
        }

        // Orientar la nave usando aletas
        lock steering to lookdirup(steerVec, facing:topvector).

        // Ajuste dinámico del AoA según altitud
        if altitude > 40000 {
            set aoa to 35.
        } else if altitude > 30000 {
            set aoa to 25.
        } else if altitude > 20000 {
            set aoa to 15.
        }

        wait 0.1. // Corrección ultrarrápida
    }

    print "Corrección aerodinámica finalizada a 20 km".
}







// --- Corrección de rumbo con motores ---
function dosteering {
    print "Corrección precisa de rumbo con motores".
    
    // Orientar hacia el vector de error
    until abs(latError()) < 0.05 and abs(lngError()) < 0.05 {
        // Vector desde impacto previsto hacia el punto de aterrizaje
        local errorVec is landingsite:position - getImpact():position.
        
        // Orientar hacia ese vector
        lock steering to lookdirup(errorVec:normalized, facing:topvector).
        
        // Esperar hasta estar bien alineado (menos de 2 grados de diferencia)
        wait until vAng(ship:facing:vector, errorVec:normalized) < 2.
        
        // Encender motores a baja potencia mientras corrige
        lock throttle to 0.07.
        
        // Recalcular continuamente hasta que el error sea suficientemente pequeño
        wait 2.
    }
    
    // Apagar motores al llegar al objetivo
    lock throttle to 0.
    print "Corrección precisa completada".
}



// --- Boostback ---
function doboostback {
    
    toggle ag2.
    
    wait .1.
    toggle ag2.
    lock steering to heading(90,180).
    lock impact to addons:tr:impactpos.
    
    print "Descenso iniciado".
    rcs on.
    
    toggle ag3.
    lock throttle to .5.
    
    wait until vAng(ship:facing:vector, heading(90,180):vector) <=20. {
        print "boostback".
        lock throttle to 1.
        wait 8.
    }
    wait 44.
    toggle ag2.
    wait until (impact:lng - tower:lng) <= .1. 
    wait until (tower:lng - impact:lng) >= .2. 
    lock throttle to 0.
    docorrection().
    print "Boostback Completado".
    lock aoa to 30.
}

// --- Corrección final ---
// --- Corrección final ---
function docorrection {
    dosteering().
    print "Corrección inicial con motores completada".

    // 🔄 Bucle de corrección persistente hasta el hoverslam
    until altitude < 25000 {
        local errorVec is landingsite:position - getImpact():position.
        lock steering to lookdirup(errorVec:normalized, facing:topvector).
        wait 0.2.
    }

    print "Entrando en fase aerodinámica y hoverslam".
    lock steering to srfRetrograde.
    wait until altitude <= 30000.
    stage.
    wait 2.
    stage.
 
    doland().
}


// --- Apagado ---
function doshutdown {
    rcs on.
    lock steering to up.
    lock throttle to 0.
    wait until ship:velocity:surface:mag <= .3.
    print "El Booster ha aterrizado".
    print "----------------------------------".
print "    ______                        ".
print "    |/|\|/                        ".
print "    |/|\|_____ -|-|-              ".
print "    |/|\|%%%%/  | |               ".
print "    |/|\|       | |               ".
print "    |/|\|       |_|               ".
print "    |/|\|       |_|               ".
print "    |/|\|       | |               ".
print "    |/|\|       | |               ".
print "    |/|\|       | |               ".
print "    |/|\|        *                ".
print "    |/|\|        *                ".
print "    |/|\|         *               ".
print "    |/|\|          *              ".
print "    |/|\|          *              ".
print "    |/|\|                         ".
print "    |/|\|     __   __             ".
print "    |/|\|     __   __             ".
print "    |/|\|     __   __             ".
print "    |/|\|     __   __             ".
print "    |/|\|    /=======\            ".
print "    |/|\|   /=========\           ".
print "----------------------------------".
print "Heavy Booster Catched Succesfully".   
    set ship:control:pilotmainthrottle to 0.
    shutdown.
                                              

}

// --- Ejecución principal ---
wait until altitude >= 45000.
rcs on.
lock throttle to 1. 

doboostback().
set target to "FullStack Base".
