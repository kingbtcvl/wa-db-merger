cd( dirname( @__FILE__()))



using SQLite
using DataFrames




function GetColumnNameVector( db, tablename)
    cols = SQLite.columns( db, tablename)
    return cols.name
end

function GetColumnNamesStr( db, tablename)
    cols = SQLite.columns( db, tablename)
    return join( cols.name, ", ")
end

function GetColumnNamesDiff( db₁, db₂, tablename)
    cols₁ = SQLite.columns( db₁, tablename)
    cols₂ = SQLite.columns( db₂, tablename)
    return setdiff( cols₁.name, cols₂.name)
end


function IsSortedTable( db, tablename, id)

    df = DBInterface.execute( db, "SELECT * FROM $(tablename);") |> DataFrame
    idvec = df[ :, id]
    return issorted( idvec)

end


function HasIdenticalTableStructure( db₁, db₂, tablename)

    colnames₁ = GetColumnNameVector( db₁, tablename)
    colnames₂ = GetColumnNameVector( db₂, tablename)
    res = colnames₁ == colnames₂
    res2 = isempty( setdiff( colnames₂, colnames₁))
    res3 = isempty( setdiff( colnames₁, colnames₂))

    if res == false
        println( "Warning: $(tablename) does not have the same structure in both databases.")
        if res2 == true
            println( "However, all columns that exisist in the second database also exist in the first one!")
            if res3 == true
                println( "Only the order of the columns is different!")
            end
        end
    #else
        #println( "The table structure is identical!")
    end

    return res

end



function GetSqliteShema( db)
    sqliteshema = DBInterface.execute( db, "SELECT * FROM sqlite_schema;") |> DataFrame
    return sqliteshema
end



function GetAllTables( db)
    sqls_tmp = DBInterface.execute( db, "SELECT * FROM sqlite_schema WHERE type = 'table';") |> DataFrame
    return sqls_tmp.name
end


function GetAllNonemptyTables( db, tablenames)

    res = String[]

    for tn in tablenames
        if !IsEmptyTable( db, tn)
            push!( res, tn)
        end
    end

    return sort( res)

end


function SQL_IsEmptyTable( db, tablename)
    df = DBInterface.execute(db, "SELECT * FROM $(tablename);") |> DataFrame
    return isempty( df)
end


function SQL_GetAllNonemptyTables( db)

    sqlshema = DBInterface.execute(db, "SELECT * FROM sqlite_schema WHERE type = 'table';") |> DataFrame
    res = String[]

    for tn in sqlshema.name
        if !SQL_IsEmptyTable( db, tn)
            push!( res, tn)
        end
    end

    return sort( res)

end


















function ColumnSetDiff( db₁, db₂, tablename)

    cols₁ = SQLite.columns( db₁, tablename)
    cols₂ = SQLite.columns( db₂, tablename)

    return setdiff(cols₁.name, cols₂.name)
end

function HasIdenticalColumns( db₁, db₂, tablename)

    cols₁ = SQLite.columns( db₁, tablename)
    cols₂ = SQLite.columns( db₂, tablename)

    return cols₁.name == cols₂.name

end


function HasPermutedColumns( db₁, db₂, tablename)

    cols₁ = SQLite.columns( db₁, tablename)
    cols₂ = SQLite.columns( db₂, tablename)
    res1 = cols₁.name != cols₂.name
    res2 = isempty( setdiff(cols₁.name, cols₂.name))
    res3 = isempty( setdiff(cols₂.name, cols₁.name))

    return res1 && res2 && res3

end


function HasAdditionalDB1Columns( db₁, db₂, tablename)

    cols₁ = SQLite.columns( db₁, tablename)
    cols₂ = SQLite.columns( db₂, tablename)
    res1 = isempty( setdiff(cols₁.name, cols₂.name))
    res2 = isempty( setdiff(cols₂.name, cols₁.name))

    return !res1 && res2

end


function HasAdditionalDB2Columns( db₁, db₂, tablename)

    cols₁ = SQLite.columns( db₁, tablename)
    cols₂ = SQLite.columns( db₂, tablename)
    res1 = isempty( setdiff(cols₁.name, cols₂.name))
    res2 = isempty( setdiff(cols₂.name, cols₁.name))

    return res1 && !res2

end


function IsEmptyTable( db, tablename)
    df = DBInterface.execute(db, "SELECT * FROM $(tablename);") |> DataFrame
    return isempty( df)
end



function GetAllTables( db)
    sqls_tmp = DBInterface.execute( db, "SELECT * FROM sqlite_schema WHERE type = 'table';") |> DataFrame
    return sqls_tmp.name
end


function GetAllNonemptyTables( db, tablenames)

    res = String[]

    for tn in tablenames
        if !IsEmptyTable( db, tn)
            push!( res, tn)
        end
    end

    return sort( res)

end


function GetAllTablesWithIdenticalCloumns( db₁, db₂, tablenames)

    res = String[]

    for tn in tablenames
        if HasIdenticalColumns( db₁, db₂, tn)
            push!( res, tn)
        end
    end

    return sort( res)

end


function GetAllTablesWithPermutedCloumns( db₁, db₂, tablenames)

    res = String[]

    for tn in tablenames
        if HasPermutedColumns( db₁, db₂, tn)
            push!( res, tn)
        end
    end

    return sort( res)

end


function GetAllTablesWithAdditionalDB1Cloumns( db₁, db₂, tablenames)

    res = String[]

    for tn in tablenames
        if HasAdditionalDB1Columns( db₁, db₂, tn)
            push!( res, tn)
        end
    end

    return sort( res)

end


function GetAllTablesWithAdditionalDB2Cloumns( db₁, db₂, tablenames)

    res = String[]

    for tn in tablenames
        if HasAdditionalDB2Columns( db₁, db₂, tn)
            push!( res, tn)
        end
    end

    return sort( res)

end



function StructureAnalysis( db₁, db₂)

    tables₁ = GetAllTables( db₁)
    tables₂ = GetAllTables( db₂)
    newtables₁ = setdiff( tables₁, tables₂)
    newtables₂ = setdiff( tables₂, tables₁)
    nonempty_tables₁ = GetAllNonemptyTables( db₁, newtables₁)
    nonempty_tables₂ = GetAllNonemptyTables( db₂, newtables₂)
    jointtables = intersect( tables₁, tables₂)
    jointidentical = GetAllTablesWithIdenticalCloumns( db₁, db₂, jointtables)
    jointpermuted = GetAllTablesWithPermutedCloumns( db₁, db₂, jointtables)
    nonempty_jointpermuted = GetAllNonemptyTables( db₂, jointpermuted)
    jointextdb1 = GetAllTablesWithAdditionalDB1Cloumns( db₁, db₂, jointtables)
    nonempty_jointextdb1 = GetAllNonemptyTables( db₂, jointextdb1)
    jointextdb2 = GetAllTablesWithAdditionalDB2Cloumns( db₁, db₂, jointtables)
    nonempty_jointextdb2 = GetAllNonemptyTables( db₂, jointextdb2) 


    println( "All tables, which are part of the first database but not part of the second:")
    print( join( newtables₁, ", "))
    println( "\n")
    println( "All non-empty tables of that:")
    print( join( nonempty_tables₁, ", "))
    println( "\n\n\n")
    println( "All tables, which are part of the second database but not part of the first:")
    print( join( newtables₂, ", "))
    println( "\n")
    println( "All non-empty tables of that:")
    print( join( nonempty_tables₂, ", "))
    println( "\n\n\n")
    println( "All tables, which both databases have in common:")
    print( join( jointtables, ", "))
    println( "\n")
    println( "All common tables with identical column structure:")
    print( join( jointidentical, ", "))
    println( "\n")
    println( "Alle common tables with the same, but permuted table structure:")
    print( join( jointpermuted, ", "))
    println( "\n")
    println( "Alle common tables with the same, but permuted table structure, which are non-empty in the second database:")
    print( join( nonempty_jointpermuted, ", "))
    println( "\n")
    println( "All common tables, in which the first database contains addional columns:")
    print( join( jointextdb1, ", "))
    println( "\n")
    println( "All common tables, in which the first database contains addional columns and which are non-empty in the second database:")
    print( join( nonempty_jointextdb1, ", "))
    println( "\n")
    println( "All common tables, in which the second database contains addional columns:")
    print( join( jointextdb2, ", "))
    println( "\n")
    println( "All common tables, in which the second database contains addional columns and which are non-empty in the first database:")
    print( join( nonempty_jointextdb2, ", "))


end


function ShowAllNonemptyTables( db)

    nonemptytables = SQL_GetAllNonemptyTables( db)

    println( "All non-empty tables:")
    println( "")
    for nemtytab in nonemptytables
        println( nemtytab)
    end

end



function ShowTableDifference( db₁, db₂, tablename)

    newcols = join( ColumnSetDiff( db₁, db₂, tablename), ", ")
    obscols = join( ColumnSetDiff( db₂, db₁, tablename), ", ")
    println( "Tables: $(tablename)")
    println( "New columns: $(newcols)")
    println( "Obsolete columns: $(obscols)")
    println( "\n")

end


