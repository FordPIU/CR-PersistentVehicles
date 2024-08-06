function Print(...)
    if Config.Debug then
        print(...)
    end
end

function Warn(...)
    if Config.Debug then
        warn(...)
    end
end
