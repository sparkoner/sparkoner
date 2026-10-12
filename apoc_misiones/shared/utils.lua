Utils = {}

-- Convierte un valor de configuración en un número según el tamaño del grupo.
-- Acepta un número fijo o una tabla { base = X, perMember = Y }:
-- resultado = base + perMember * (miembros - 1)
function Utils.Scale(value, members)
    if type(value) == 'table' then
        local extra = math.max((members or 1) - 1, 0)
        return math.max(0, math.floor((value.base or 0) + (value.perMember or 0) * extra + 0.0001))
    end
    return value or 0
end

function Utils.Dist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function Utils.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    return ('%02d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end
