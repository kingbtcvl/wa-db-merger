cd( dirname( @__FILE__()))



using SQLite
using DataFrames



include( "structuretools.jl")
include( "sqlfuncs.jl")





# database, which severes as the model for the conversion
# as far as the structure is concerned
db_model = SQLite.DB( "db_wa.db")

# old databse
db_old = SQLite.DB( "db_gbwa.db")

# inconsistent database, which only contains tables with data
#db_merged_inconsistent = SQLite.DB( "db_merged_inconsistent.db")

# new database, which contains the data of the merged
# but inconsistent database as well as the structure of the
# model database
#db_merged = SQLite.DB( "db_merged.db")







ShowAllNonemptyTables( db_model)

##=
StructureAnalysis( db_model, db_old)

ShowTableDifference( db_model, db_old, "chat")
ShowTableDifference( db_model, db_old, "message")
ShowTableDifference( db_model, db_old, "message_ephemeral_setting")
ShowTableDifference( db_model, db_old, "message_future")
ShowTableDifference( db_model, db_old, "message_media")
ShowTableDifference( db_model, db_old, "message_template")
ShowTableDifference( db_model, db_old, "user_device_info")
# =#



#=
sqlshema1 = GetSqliteShema( db_model)
sqlshema2 = GetSqliteShema( db_merged)
# =#