cd( dirname( @__FILE__()))



using SQLite
using DataFrames







function ContinueIdsFrom!( df, idname, from)
    df[!, idname] = from .+ collect( 1:nrow( df))
end



function ShiftIds!( df, idname, shift)
    df[!, idname] = df[!, idname] .+ shift
end



function ReplaceIDs!( df, idname, shift::Int64; skipids=[])

        for drow in eachrow( df)
            el = drow[idname]

            if !ismissing( el) && el ∉ skipids
                drow[idname] = el + shift
            end
        end

end


function ReplaceIDs!( df, idname, id_rplc::DataFrame; skipids=[])

    oids = id_rplc._id_wa
    nids = id_rplc._id_gbwa

    for drow in eachrow( df)
        i = findfirst( isequal(drow[ idname]), oids)
        if i ≠ nothing
            drow[ idname] = nids[i]
        elseif !ismissing(drow[idname]) && drow[idname] ∉ skipids
            println( "$(idname): ID $(drow[idname]) was skipped!")
        end
    end

end






function SQL_DropAllTriggers!( db)

    sqlshema = DBInterface.execute(db, "SELECT * FROM sqlite_schema WHERE type = 'trigger';") |> DataFrame

    for tn in sqlshema.name
        DBInterface.execute(db, "DROP TRIGGER $(tn);")
    end

end


function SQL_DropAllViews!( db)

    sqlshema = DBInterface.execute(db, "SELECT * FROM sqlite_schema WHERE type = 'view';") |> DataFrame

    for tn in sqlshema.name
        DBInterface.execute(db, "DROP VIEW $(tn);")
    end

end


function SQL_CreateAllTriggersByCopy!( db, db_model)

    sqlshema = DBInterface.execute( db_model, "SELECT * FROM sqlite_schema WHERE type = 'trigger';") |> DataFrame

    for sqlcmd in sqlshema.sql
        DBInterface.execute( db, sqlcmd)
    end
    
end


function SQL_CreateAllTriggersAndViewsByCopy!( db, db_model)

    sqlshema = DBInterface.execute( db_model, "SELECT * FROM sqlite_schema WHERE type = 'trigger' OR type = 'view';") |> DataFrame

    for sqlcmd in sqlshema.sql
        DBInterface.execute( db, sqlcmd)
    end
    
end


function SQL_CreateNewTableByTemplate!( db, tablename, db_tmplt)
    sqlshema = DBInterface.execute( db_tmplt, "SELECT * FROM sqlite_schema WHERE type='table' AND name='$(tablename)';") |> DataFrame
    DBInterface.execute( db, only( sqlshema.sql))
end



function SQL_InsertDataIntoTable!( db, tablename, df)

    qmstr = join( ["?" for i=1:ncol( df)], ", ")
    stmt = SQLite.Stmt(db, "INSERT INTO $(tablename) VALUES($(qmstr));")

    for drow in eachrow( df)
        DBInterface.execute( stmt, values(drow))
    end

end



function SQL_UpdateRowsInTable!( db, tablename, id, df)

    dfnames = names( df)
    updstr = join( [nm * " = ?" for nm in dfnames[2:end]], ", ")
    stmt = SQLite.Stmt(db, "UPDATE $(tablename) SET $(updstr) WHERE $(id) = ?;")

    for drow in eachrow( df)
        val = values( drow)
        DBInterface.execute( stmt, val[vcat(2:end, 1)])
    end

end



function SQL_UpdateSQLiteSequence( db, tablename, seqid)
    DBInterface.execute( db, "UPDATE sqlite_sequence SET seq = $(seqid) WHERE name = '$(tablename)';")
end



function SQL_DeleteAllTableData!( db, tablename)
    DBInterface.execute( db, "DELETE FROM $(tablename);")
end


function SQL_EmptyAllTables!( db)

    sqlshema = DBInterface.execute( db_model, "SELECT * FROM sqlite_schema WHERE type = 'table';") |> DataFrame

    for tabname in sqlshema.name
        SQL_DeleteAllTableData!( db, tabname)
    end

end



function SQL_DeleteRowsByIDs!( db, tablename, colname, ids)

    stmt = SQLite.Stmt(db, "DELETE FROM $(tablename) WHERE $(colname) = ?;")

    for id in ids
        DBInterface.execute( stmt, [id])
    end

end



function SQL_SelectAllTableData( db::SQLite.DB, tablename::String)
    colsnamestr_db = GetColumnNamesStr( db, tablename)
    db_data = DBInterface.execute(db, "SELECT $(colsnamestr_db) FROM $(tablename);") |> DataFrame
    return db_data
end


function SQL_SelectAllTableData( db::SQLite.DB, tablename::String, orderby::String)
    colsnamestr_db = GetColumnNamesStr( db, tablename)
    db_data = DBInterface.execute(db, "SELECT $(colsnamestr_db) FROM $(tablename) ORDER BY $(orderby);") |> DataFrame
    return db_data
end


function SQL_SelectAllTableData( db::SQLite.DB, tablename::String, colsnamestr::String, orderby::String)
    db_data = DBInterface.execute(db, "SELECT $(colsnamestr) FROM $(tablename) ORDER BY $(orderby);") |> DataFrame
    return db_data
end


function SQL_SelectAllTableData( tablename::String, orderby::String)

    colsnamestr_gbwa = GetColumnNamesStr( db_gbwa, tablename)
    wa_data = SQL_SelectAllTableData( db_wa, tablename, colsnamestr_gbwa, orderby)
    gbwa_data = SQL_SelectAllTableData( db_gbwa, tablename, colsnamestr_gbwa, orderby)

    return wa_data, gbwa_data

end



function SQL_SelectShiftOfTable( db, tablename)
    df = DBInterface.execute( db, "SELECT * FROM sqlite_sequence WHERE name = '$(tablename)';") |> DataFrame
    return only( df.seq)
end



