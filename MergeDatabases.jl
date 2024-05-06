cd( dirname( @__FILE__()))



using SQLite
using DataFrames



include( "structuretools.jl")
include( "sqlfuncs.jl")





# variable, which controls if the changes
# should be carried out in the sql database
#dosql = false    # Testing and debugging mode
dosql = true      # WARNING: ALWAYS MAKE A COPY OF YOUR DATABASE
                  # BEFORE YOU DECIDE DO CHANGE IT



db_gbwa = SQLite.DB( "db_gbwa.db")
db_wa = SQLite.DB( "db_wa.db")





#DBInterface.execute(db_gbwa, "VACUUM main INTO 'test.db';")






###################################################################################################
##=
# Deleting all triggers

if dosql
    SQL_DropAllTriggers!( db_gbwa)
end



println( "All triggers have successfully been deleted.\n")
# =#
###################################################################################################



##################################################################################################
##=
# Manually making inconsistent tables consistent

if dosql
    # Making table "chat" consistent
    DBInterface.execute(db_gbwa, "ALTER TABLE chat ADD unseen_comment_message_count INTEGER;")
    DBInterface.execute(db_gbwa, "UPDATE chat SET unseen_comment_message_count = 0 WHERE hidden = 0;")
    DBInterface.execute(db_gbwa, "ALTER TABLE chat ADD chat_origin TEXT;")

    # Making table "message" consistent
    DBInterface.execute(db_gbwa, "ALTER TABLE message ADD view_mode INTEGER;")

    # Making table "message_ephemeral_setting" consistent
    DBInterface.execute(db_gbwa, "ALTER TABLE message_ephemeral_setting ADD ephemeral_trigger INTEGER;")
    DBInterface.execute(db_gbwa, "ALTER TABLE message_ephemeral_setting ADD ephemeral_initiated_by_me INTEGER;")

    # Making table "message_future" consistent
    DBInterface.execute(db_gbwa, "ALTER TABLE message_future ADD edit_version INTEGER;")

    # Making table "message_media" consistent
    DBInterface.execute(db_gbwa, "ALTER TABLE message_media ADD sticker_flags INTEGER;")

    # Making table "message_template" consistent
    DBInterface.execute(db_gbwa, "ALTER TABLE message_template ADD mask_linked_devices INTEGER;")

    # Making table "user_device_info" consistent
    DBInterface.execute(db_gbwa, "ALTER TABLE user_device_info ADD account_encryption_type INTEGER;")
    DBInterface.execute(db_gbwa, "UPDATE user_device_info SET account_encryption_type = 0;")
end



println( "All inconsistent tables have successfully been made consistent.\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "jid":
tn = "jid"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

tmp = antijoin( tmpdf_wa, tmpdf_gbwa, on=:raw_string)
ContinueIdsFrom!( tmp, "_id", tmpdf_gbwa._id[end])
jid_seqid = tmp[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmp)
end



# Determining the mapping of the particpiant IDs
# (Which participant ID (jid) in db_wa.db corresponds to which participant ID (jid) in db_gbwa.db?)
jc = [:_id, :raw_string]
jid_rplc₁ = innerjoin( tmpdf_wa[:, jc], tmp[:, jc], on=:raw_string, renamecols = "_wa" => "_gbwa")
jid_rplc₂ = innerjoin( tmpdf_wa[:, jc], tmpdf_gbwa[:, jc], on=:raw_string, renamecols = "_wa" => "_gbwa")
jid_rplc = vcat( jid_rplc₁, jid_rplc₂)
sort!( jid_rplc, :_id_wa)



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "chat":
tn = "chat"
chat_wa, chat_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( chat_wa, "jid_row_id", jid_rplc)
chat_tmp = antijoin( chat_wa, chat_gbwa, on=:jid_row_id)
sort!( chat_tmp, :_id)
ContinueIdsFrom!( chat_tmp, "_id", chat_gbwa._id[end])



# Determining the mapping of the chat IDs
# (Which chat id in db_wa.db will be converted to which chat id in db_gbwa.db?)
jc = [:_id, :jid_row_id]
chat_rplc₁ = innerjoin( chat_wa[:, jc], chat_tmp[:, jc], on=:jid_row_id, renamecols = "_wa" => "_gbwa")
chat_rplc₂ = innerjoin( chat_wa[:, jc], chat_gbwa[:, jc], on=:jid_row_id, renamecols = "_wa" => "_gbwa")
chat_rplc = vcat( chat_rplc₁, chat_rplc₂)
sort!( chat_rplc, :_id_wa)


chat_wa_not_hidden = semijoin( chat_wa[chat_wa.hidden .== 0, :], chat_gbwa, on=:jid_row_id)
ReplaceIDs!( chat_wa_not_hidden, "_id", chat_rplc)



println( "Table $(tn) has been successfully prepared!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message":
tn = "message"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

deleteat!( tmpdf_wa, 1)
message_shift = SQL_SelectShiftOfTable( db_gbwa, tn) - 1
ShiftIds!( tmpdf_wa, "_id", message_shift)
ReplaceIDs!( tmpdf_wa, "chat_row_id", chat_rplc)
ReplaceIDs!( tmpdf_wa, "sender_jid_row_id", jid_rplc, skipids=[0])
message_sort_shift = tmpdf_gbwa.sort_id[end] - 1
ShiftIds!( tmpdf_wa, "sort_id", message_sort_shift)
message_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_add_on":
tn = "message_add_on"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

message_add_on_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", message_add_on_shift)
ReplaceIDs!( tmpdf_wa, "chat_row_id", chat_rplc)
ReplaceIDs!( tmpdf_wa, "sender_jid_row_id", jid_rplc, skipids=[-1])
ReplaceIDs!( tmpdf_wa, "parent_message_row_id", message_shift, skipids=[1])
message_add_on_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "chat":
tn = "chat"

# ReplaceIDs!( chat_tmp, "jid_row_id", jid_rplc) # (already done above now, DO NOT do it again here!)
ReplaceIDs!( chat_wa_not_hidden, "display_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "last_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "last_read_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "last_read_receipt_sent_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "last_important_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "change_number_notified_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "last_read_ephemeral_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "last_message_reaction_row_id", message_add_on_shift)
ReplaceIDs!( chat_wa_not_hidden, "last_seen_message_reaction_row_id", message_add_on_shift)
ReplaceIDs!( chat_wa_not_hidden, "last_read_message_sort_id", message_sort_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "display_message_sort_id", message_sort_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "last_message_sort_id", message_sort_shift, skipids=[1])
ReplaceIDs!( chat_wa_not_hidden, "last_read_receipt_sent_message_sort_id", message_sort_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "display_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "last_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "last_read_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "last_read_receipt_sent_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "last_important_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "change_number_notified_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "last_read_ephemeral_message_row_id", message_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "last_message_reaction_row_id", message_add_on_shift)
ReplaceIDs!( chat_tmp, "last_seen_message_reaction_row_id", message_add_on_shift)
ReplaceIDs!( chat_tmp, "last_read_message_sort_id", message_sort_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "display_message_sort_id", message_sort_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "last_message_sort_id", message_sort_shift, skipids=[1])
ReplaceIDs!( chat_tmp, "last_read_receipt_sent_message_sort_id", message_sort_shift, skipids=[1])
chat_seqid = chat_tmp[end, :_id]

if dosql
    SQL_UpdateRowsInTable!( db_gbwa, tn, "_id", chat_wa_not_hidden)
    SQL_InsertDataIntoTable!( db_gbwa, tn, chat_tmp)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "call_log":
tn = "call_log"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

call_log_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", call_log_shift)
ReplaceIDs!( tmpdf_wa, "jid_row_id", jid_rplc)
ReplaceIDs!( tmpdf_wa, "group_jid_row_id", jid_rplc, skipids=[0])
ReplaceIDs!( tmpdf_wa, "call_creator_device_jid_row_id", jid_rplc)
#ReplaceIDs!( tmpdf_wa, "call_link_row_id", call_link_shift)
call_log_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "group_participant_user":
tn = "group_participant_user"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

tmpdf_wa₁ = DBInterface.execute(db_wa, "SELECT DISTINCT group_jid_row_id FROM $(tn);") |> DataFrame
tmpid = tmpdf_wa₁.group_jid_row_id
ReplaceIDs!( tmpdf_wa₁, "group_jid_row_id", jid_rplc)

group_participant_user_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", group_participant_user_shift)
ReplaceIDs!( tmpdf_wa, "group_jid_row_id", jid_rplc)
ReplaceIDs!( tmpdf_wa, "user_jid_row_id", jid_rplc)
group_participant_user_seqid = tmpdf_wa[end, :_id]
group_participant_user_tmpid = tmpdf_gbwa[ in.( tmpdf_gbwa[:, :group_jid_row_id], Ref(tmpid)), :_id]

if dosql
    SQL_DeleteRowsByIDs!( db_gbwa, tn, "group_jid_row_id", tmpid)
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "group_past_participant_user":
tn = "group_past_participant_user"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

group_past_participant_user_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", group_past_participant_user_shift)
ReplaceIDs!( tmpdf_wa, "group_jid_row_id", jid_rplc)
ReplaceIDs!( tmpdf_wa, "user_jid_row_id", jid_rplc)
group_past_participant_user_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_poll_option":
tn = "message_poll_option"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

message_poll_option_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", message_poll_option_shift)
ReplaceIDs!( tmpdf_wa, "message_row_id", message_shift, skipids=[1])
message_poll_option_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_vcard":
tn = "message_vcard"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

message_vcard_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", message_vcard_shift)
ReplaceIDs!( tmpdf_wa, "message_row_id", message_shift, skipids=[1])
message_vcard_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "call_log_participant_v2":
tn = "call_log_participant_v2"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

call_log_participant_v2_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", call_log_participant_v2_shift)
ReplaceIDs!( tmpdf_wa, "call_log_row_id", call_log_shift)
ReplaceIDs!( tmpdf_wa, "jid_row_id", jid_rplc)
call_log_participant_v2_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "frequent":
tn = "frequent"
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

if dosql
    SQL_DeleteAllTableData!( db_gbwa, tn)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "frequents":
tn = "frequents"
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

if dosql
    SQL_DeleteAllTableData!( db_gbwa, tn)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "group_participant_device":
tn = "group_participant_device"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
HasIdenticalTableStructure( db_wa, db_gbwa, tn)

group_participant_device_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", group_participant_device_shift)
ReplaceIDs!( tmpdf_wa, "group_participant_row_id", group_participant_user_shift)
ReplaceIDs!( tmpdf_wa, "device_jid_row_id", jid_rplc)
group_participant_device_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_DeleteRowsByIDs!( db_gbwa, tn, "group_participant_row_id", group_participant_user_tmpid)
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "media_refs":
tn = "media_refs"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

media_refs_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", media_refs_shift)
media_refs_seqid = tmpdf_wa[end, :_id]

if dosql
    # Manually fixing the broken things here:

    DBInterface.execute( db_gbwa, "DELETE FROM $(tn) WHERE _id = 587;")
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET ref_count = 3 WHERE _id = 1;")
    DBInterface.execute( db_gbwa, "DELETE FROM $(tn) WHERE _id = 535;")
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET ref_count = 10 WHERE _id = 59;")
    DBInterface.execute( db_gbwa, "DELETE FROM $(tn) WHERE _id = 544;")
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET ref_count = 3 WHERE _id = 86;")
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET path = REPLACE( path, '/storage/emulated/0/GBWhatsApp/Media/GBWhatsApp', '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp') WHERE _id <= 526;")
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET path = REPLACE( path, '/storage/emulated/0/Android/media/com.gbwhatsapp/GBWhatsApp/Media/GBWhatsApp', '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp') WHERE _id >= 527;")
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)

    # Animated Gifs
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET path = REPLACE(path, 'Animated Gifs/VID', 'Animated Gifs/Private/VID')" *
    "WHERE INSTR(path, 'Animated Gifs/VID') > 0;")
    # Audio
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET path = REPLACE(path, 'Audio/AUD', 'Audio/Private/AUD')" *
    "WHERE INSTR(path, 'Audio/AUD') > 0;")
    # Images
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET path = REPLACE(path, 'Images/IMG', 'Images/Private/IMG')" *
    "WHERE INSTR(path, 'Images/IMG') > 0;")
    # Video
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET path = REPLACE(path, 'Video/VID', 'Video/Private/VID')" *
    "WHERE INSTR(path, 'Video/VID') > 0;")
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_add_on_poll_vote_selected_option":
tn = "message_add_on_poll_vote_selected_option"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

message_add_on_poll_vote_selected_option_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", message_add_on_poll_vote_selected_option_shift)
ReplaceIDs!( tmpdf_wa, "message_add_on_row_id", message_add_on_shift)
ReplaceIDs!( tmpdf_wa, "message_poll_option_id", message_poll_option_shift)
message_add_on_poll_vote_selected_option_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_add_on_receipt_device":
tn = "message_add_on_receipt_device"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "receipt_device_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

message_add_on_receipt_device_shift = SQL_SelectShiftOfTable( db_gbwa, tn)

ShiftIds!( tmpdf_wa, "receipt_device_id", message_add_on_receipt_device_shift)
ReplaceIDs!( tmpdf_wa, "message_add_on_row_id", message_add_on_shift)
ReplaceIDs!( tmpdf_wa, "receipt_device_jid_row_id", jid_rplc)
message_add_on_receipt_device_seqid = tmpdf_wa[end, :receipt_device_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_link":
tn = "message_link"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

message_link_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", message_link_shift)
ReplaceIDs!( tmpdf_wa, "chat_row_id", chat_rplc)
ReplaceIDs!( tmpdf_wa, "message_row_id", message_shift, skipids=[1])
message_link_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_mentions":
tn = "message_mentions"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

message_mentions_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", message_mentions_shift)
ReplaceIDs!( tmpdf_wa, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf_wa, "jid_row_id", jid_rplc)
message_mentions_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_quoted":
tn = "message_quoted"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf, "chat_row_id", chat_rplc)
ReplaceIDs!( tmpdf, "parent_message_chat_row_id", chat_rplc)
ReplaceIDs!( tmpdf, "sender_jid_row_id", jid_rplc, skipids=[0])
#ReplaceIDs!( tmpdf, "payment_transaction_id", payment_transaction_shift)
message_quoted_seqid = tmpdf[end, :message_row_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_vcard_jid":
tn = "message_vcard_jid"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

message_vcard_jid_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", message_vcard_jid_shift)
ReplaceIDs!( tmpdf_wa, "vcard_jid_row_id", jid_rplc)
ReplaceIDs!( tmpdf_wa, "vcard_row_id", message_vcard_shift, skipids=[-1])
ReplaceIDs!( tmpdf_wa, "message_row_id", message_shift, skipids=[1])
message_vcard_jid_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "receipt_device":
tn = "receipt_device"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

receipt_device_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", receipt_device_shift)
ReplaceIDs!( tmpdf_wa, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf_wa, "receipt_device_jid_row_id", jid_rplc)
receipt_device_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "receipt_orphaned":
tn = "receipt_orphaned"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

receipt_orphaned_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", receipt_orphaned_shift)
ReplaceIDs!( tmpdf_wa, "chat_row_id", chat_rplc)
ReplaceIDs!( tmpdf_wa, "receipt_device_jid_row_id", jid_rplc)
ReplaceIDs!( tmpdf_wa, "receipt_recipient_jid_row_id", jid_rplc)
receipt_orphaned_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "receipt_user":
tn = "receipt_user"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

receipt_user_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", receipt_user_shift)
ReplaceIDs!( tmpdf_wa, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf_wa, "receipt_user_jid_row_id", jid_rplc)
receipt_user_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "receipts":
tn = "receipts"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

receipts_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", receipts_shift)
receipts_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "status":
tn = "status"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

status_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", status_shift)
ReplaceIDs!( tmpdf_wa, "jid_row_id", jid_rplc)
ReplaceIDs!( tmpdf_wa, "message_table_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf_wa, "last_read_message_table_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf_wa, "last_read_receipt_sent_message_table_id", message_shift, skipids=[1])
# Manually fixing the broken things here:
ReplaceIDs!( tmpdf_wa, "first_unread_message_table_id", message_shift, skipids=[-9223372036854775808])
ReplaceIDs!( tmpdf_wa, "autodownload_limit_message_table_id", message_shift, skipids=[-9223372036854775808])
status_seqid = tmpdf_wa[end, :_id]

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "user_device":
tn = "user_device"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

user_device_shift = SQL_SelectShiftOfTable( db_gbwa, tn)
ShiftIds!( tmpdf_wa, "_id", user_device_shift)
ReplaceIDs!( tmpdf_wa, "user_jid_row_id", jid_rplc)
ReplaceIDs!( tmpdf_wa, "device_jid_row_id", jid_rplc)
tmpdf = vcat( tmpdf_gbwa, antijoin( tmpdf_wa, tmpdf_gbwa, on=[:user_jid_row_id, :device_jid_row_id, :key_index]))
sort!( tmpdf, :_id)
user_device_seqid = tmpdf[end, :_id]

if dosql
    SQL_DeleteAllTableData!( db_gbwa, tn)
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "audio_data":
tn = "audio_data"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "call_unknown_caller":
tn = "call_unknown_caller"
tmpdf = SQL_SelectAllTableData( db_wa, tn, "call_log_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "call_log_row_id", call_log_shift)

if dosql
    SQL_CreateNewTableByTemplate!( db_gbwa, tn, db_wa)
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "group_notification_version":
tn = "group_notification_version"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "group_jid_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf_wa, "group_jid_row_id", jid_rplc)
tmpdf_wa₁ = semijoin( tmpdf_wa, tmpdf_gbwa, on=:group_jid_row_id)
tmpdf_wa₂ = antijoin( tmpdf_wa, tmpdf_gbwa, on=:group_jid_row_id)

if dosql
    SQL_UpdateRowsInTable!( db_gbwa, tn, "group_jid_row_id", tmpdf_wa₁)
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa₂)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "jid_map":
tn = "jid_map"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "lid_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf_wa, "lid_row_id", jid_rplc)
ReplaceIDs!( tmpdf_wa, "jid_row_id", jid_rplc)
tmpdf = vcat( tmpdf_gbwa, antijoin( tmpdf_wa, tmpdf_gbwa, on=[:lid_row_id, :jid_row_id]))
sort!( tmpdf, :lid_row_id)


if dosql
    SQL_DeleteAllTableData!( db_gbwa, tn)
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "media_hash_thumbnail":
tn = "media_hash_thumbnail"
tmpdf = SQL_SelectAllTableData( db_wa, tn)
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_add_on_poll_vote":
tn = "message_add_on_poll_vote"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_add_on_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_add_on_row_id", message_add_on_shift)

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_add_on_reaction":
tn = "message_add_on_reaction"
tmpdf, _= SQL_SelectAllTableData( tn, "message_add_on_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_add_on_row_id", message_add_on_shift)

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_call_log":
tn = "message_call_log"
tmpdf = SQL_SelectAllTableData( db_wa, tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf, "call_log_row_id", call_log_shift)

if dosql
    SQL_CreateNewTableByTemplate!( db_gbwa, tn, db_wa)
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_details":
tn = "message_details"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf, "author_device_jid", jid_rplc)

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_edit_info":
tn = "message_edit_info"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_forwarded":
tn = "message_forwarded"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_location":
tn = "message_location"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf, "chat_row_id", chat_rplc)

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_media":
tn = "message_media"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf, "chat_row_id", chat_rplc)
#ReplaceIDs!( tmpdf, "multicast_id", multicast_shift)

if dosql
    # Manually fixing the broken things here:


    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE( file_path, 'Media/GBWhatsApp', 'Media/WhatsApp');")
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)

    # Animated Gifs
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE(file_path, 'Animated Gifs/VID', 'Animated Gifs/Private/VID')" *
    "WHERE INSTR(file_path, 'Animated Gifs/VID') > 0;")
    # Audio
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE(file_path, 'Audio/AUD', 'Audio/Private/AUD')" *
    "WHERE INSTR(file_path, 'Audio/AUD') > 0;")
    # Images
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE(file_path, 'Images/IMG', 'Images/Private/IMG')" *
    "WHERE INSTR(file_path, 'Images/IMG') > 0;")
    # Video
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE(file_path, 'Video/VID', 'Video/Private/VID')" *
    "WHERE INSTR(file_path, 'Video/VID') > 0;")
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_poll":
tn = "message_poll"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_quoted_media":
tn = "message_quoted_media"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    # Manually fixing the broken things here:


    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE( file_path, 'Media/GBWhatsApp', 'Media/WhatsApp');")
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)

    # Animated Gifs
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE(file_path, 'Animated Gifs/VID', 'Animated Gifs/Private/VID')" *
    "WHERE INSTR(file_path, 'Animated Gifs/VID') > 0;")
    # Audio
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE(file_path, 'Audio/AUD', 'Audio/Private/AUD')" *
    "WHERE INSTR(file_path, 'Audio/AUD') > 0;")
    # Images
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE(file_path, 'Images/IMG', 'Images/Private/IMG')" *
    "WHERE INSTR(file_path, 'Images/IMG') > 0;")
    # Video
    DBInterface.execute( db_gbwa, "UPDATE $(tn) SET file_path = REPLACE(file_path, 'Video/VID', 'Video/Private/VID')" *
    "WHERE INSTR(file_path, 'Video/VID') > 0;")
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_quoted_text":
tn = "message_quoted_text"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_revoked":
tn = "message_revoked"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf, "admin_jid_row_id", jid_rplc)

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_secret":
tn = "message_secret"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_send_count":
tn = "message_send_count"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_streaming_sidecar":
tn = "message_streaming_sidecar"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_system":
tn = "message_system"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_system_business_state":
tn = "message_system_business_state"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_system_chat_participant":
tn = "message_system_chat_participant"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf, "user_jid_row_id", jid_rplc)

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_system_group":
tn = "message_system_group"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_system_initial_privacy_provider":
tn = "message_system_initial_privacy_provider"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_system_photo_change":
tn = "message_system_photo_change"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_system_value_change":
tn = "message_system_value_change"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_text":
tn = "message_text"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "message_thumbnail":
tn = "message_thumbnail"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "mms_thumbnail_metadata":
tn = "mms_thumbnail_metadata"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "played_self_receipt":
tn = "played_self_receipt"
tmpdf, _ = SQL_SelectAllTableData( tn, "message_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf, "message_row_id", message_shift, skipids=[1])
ReplaceIDs!( tmpdf, "to_jid_row_id", jid_rplc)
ReplaceIDs!( tmpdf, "participant_jid_row_id", jid_rplc)

if dosql
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "primary_device_version":
tn = "primary_device_version"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "user_jid_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf_wa, "user_jid_row_id", jid_rplc)
tmpdf = vcat( tmpdf_gbwa, antijoin( tmpdf_wa, tmpdf_gbwa, on=:user_jid_row_id))
sort!( tmpdf, :user_jid_row_id)

if dosql
    SQL_DeleteAllTableData!( db_gbwa, tn)
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "props":
tn = "props"
tmpdf, _ = SQL_SelectAllTableData( tn, "_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

if dosql
    # Manually fixing all none-identical things here:

    propskeys = [ "async_init_migration_start_time", "frequents", "earliest_status_time", "db_migration_attempt_timestamp"]
    for pkey in propskeys
        val = only( tmpdf[ tmpdf.key .== pkey, :].value)
        DBInterface.execute( db_gbwa, "UPDATE $(tn) SET value = '$(val)' WHERE key = '$(pkey)';")
    end
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "user_device_info":
tn = "user_device_info"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "user_jid_row_id")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

ReplaceIDs!( tmpdf_wa, "user_jid_row_id", jid_rplc)
tmpdf_wa₁ = semijoin( tmpdf_wa, tmpdf_gbwa, on=:user_jid_row_id)
tmpdf_wa₂ = antijoin( tmpdf_wa, tmpdf_gbwa, on=:user_jid_row_id)

if dosql
    SQL_UpdateRowsInTable!( db_gbwa, tn, "user_jid_row_id", tmpdf_wa₁)
    SQL_InsertDataIntoTable!( db_gbwa, tn, tmpdf_wa₂)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################



###################################################################################################
##=
# Editing table "sqlite_sequence":
tn = "sqlite_sequence"
tmpdf_wa, tmpdf_gbwa = SQL_SelectAllTableData( tn, "name")
#HasIdenticalTableStructure( db_wa, db_gbwa, tn)

deleted_chat_job_seqid = only(tmpdf_gbwa[ tmpdf_gbwa.name .== "deleted_chat_job", :seq] +
                         tmpdf_wa[ tmpdf_wa.name .== "deleted_chat_job", :seq])
frequent_seqid = only(tmpdf_gbwa[ tmpdf_gbwa.name .== "frequent", :seq] +
                         tmpdf_wa[ tmpdf_wa.name .== "frequent", :seq])
frequents_seqid = only(tmpdf_gbwa[ tmpdf_gbwa.name .== "frequents", :seq] +
                         tmpdf_wa[ tmpdf_wa.name .== "frequents", :seq])
message_media_interactive_annotation_seqid = only(tmpdf_gbwa[ tmpdf_gbwa.name .== "message_media_interactive_annotation", :seq] +
                         tmpdf_wa[ tmpdf_wa.name .== "message_media_interactive_annotation", :seq])
message_media_interactive_annotation_vertex_seqid = only(tmpdf_gbwa[ tmpdf_gbwa.name .== "message_media_interactive_annotation_vertex", :seq] +
                         tmpdf_wa[ tmpdf_wa.name .== "message_media_interactive_annotation_vertex", :seq])


if dosql
    # Only changing the necessary things here:

    # "props" will only be updated with data from db_wa, but not extended
    # "group_participants" does not have any entries in db_wa
    # "group_participants_history" does not have any entries in db_wa
    SQL_UpdateSQLiteSequence( db_gbwa, "frequents", frequents_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "receipts", receipts_seqid)
    # "status_list" does not have any entries in db_wa
    SQL_UpdateSQLiteSequence( db_gbwa, "media_refs", media_refs_seqid)
    # "missed_call_logs" does not have any entries in db_wa
    SQL_UpdateSQLiteSequence( db_gbwa, "jid", jid_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "call_log", call_log_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "call_log_participant_v2", call_log_participant_v2_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "chat", chat_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "receipt_device", receipt_device_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "deleted_chat_job", deleted_chat_job_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message_media_interactive_annotation", message_media_interactive_annotation_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message_media_interactive_annotation_vertex", message_media_interactive_annotation_vertex_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message", message_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "receipt_user", receipt_user_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "group_participant_user", group_participant_user_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "group_participant_device", group_participant_device_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "status", status_seqid)
    # "missed_call_log_participant" does not have any entries in db_wa
    SQL_UpdateSQLiteSequence( db_gbwa, "user_device", user_device_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message_vcard_jid", message_vcard_jid_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "receipt_orphaned", receipt_orphaned_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message_add_on", message_add_on_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message_add_on_receipt_device", message_add_on_receipt_device_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message_quoted", message_quoted_seqid)
    # "message_quoted_mentions" does not have any entries in db_wa
    SQL_UpdateSQLiteSequence( db_gbwa, "message_mentions", message_mentions_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message_vcard", message_vcard_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "frequent", frequent_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message_link", message_link_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "group_past_participant_user", group_past_participant_user_seqid)
    # "message_add_on_orphan" does not have any entries in db_wa
    SQL_UpdateSQLiteSequence( db_gbwa, "message_poll_option", message_poll_option_seqid)
    SQL_UpdateSQLiteSequence( db_gbwa, "message_add_on_poll_vote_selected_option", message_add_on_poll_vote_selected_option_seqid)
end



println( "Table $(tn) has been successfully and completely edited!\n")
# =#
###################################################################################################





###################################################################################################
##=
# TEMPORARY FIXES for some special problems:

if dosql
    SQL_DeleteRowsByIDs!( db_gbwa, "message", "_id", [197405])
end



println( "Temporary fixes for some special problems have been carried out!\n")
# =#
###################################################################################################
