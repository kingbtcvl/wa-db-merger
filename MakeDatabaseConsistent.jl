cd( dirname( @__FILE__()))



using SQLite
using DataFrames



include( "structuretools.jl")
include( "sqlfuncs.jl")





# database, which severes as the model for the conversion
# as far as the structure is concerned
db_model = SQLite.DB( "db_wa.db")

# inconsistent database, which only contains tables with data
db_convert = SQLite.DB( "db_merged_inconsistent.db")

# new database, which contains the data of the merged
# but inconsistent database as well as the structure of the
# model database
db_res = SQLite.DB( "db_merged.db")















function NewDatabase( db₁, db₂, db_new)

    sqlshema = DBInterface.execute( db₁, "SELECT * FROM sqlite_schema WHERE type = 'table';") |> DataFrame

    tables₁ = GetAllTables( db₁)
    tables₂ = GetAllTables( db₂)
    nonempty_tables₂ = GetAllNonemptyTables( db₂, tables₂)
    jointtables = intersect( tables₁, tables₂)
    jointpermuted = GetAllTablesWithPermutedCloumns( db₁, db₂, jointtables)
    jointextdb1 = GetAllTablesWithAdditionalDB1Cloumns( db₁, db₂, jointtables)


    SQL_DropAllTriggers!( db_new)
    SQL_DropAllViews!( db_new)
    SQL_EmptyAllTables!( db_new)


    for tabname in sqlshema.name
        println( tabname)

        if tabname in nonempty_tables₂
            df_tmp = DBInterface.execute( db₂, "SELECT * FROM $(tabname);") |> DataFrame
            if tabname in jointpermuted
                # swap columns so that they have the same order as given
                # in the table tabname in the database db_model
                select!( df_tmp, SQLite.columns( db₁, tabname).name)
                println( "Columns in db_convert had a different order!")
            end
            if tabname in jointextdb1
                # Adding missing columns, which exist in the table tabname
                # in the database db_model
                addcols = ColumnSetDiff( db₁, db₂, tabname)
                for addcol in addcols
                    df_tmp[ !, addcol] .= missing
                end

                # swap columns so that they have the same order as given
                # in the table tabname in the database db_model
                select!( df_tmp, SQLite.columns( db₁, tabname).name)
                println( "Some columns in db_convert were missing!")
            end

            SQL_InsertDataIntoTable!( db_new, tabname, df_tmp)
        end
    end

    SQL_CreateAllTriggersAndViewsByCopy!( db_new, db₁)
    #DBInterface.execute( db_new, "VACUUM main INTO 'db_merged_vacuum.db';")

end


@time NewDatabase( db_model, db_convert, db_res)

