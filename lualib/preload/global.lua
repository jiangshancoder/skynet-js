function get_db_mgr()
    local rnd = math.random(1,3)
    if 1 == rnd then
        return ".db_mgr1"
    elseif 2 == rnd then
        return ".db_mgr2"
    end
    return ".db_mgr3"
end