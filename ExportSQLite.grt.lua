-- ExportSQLite: SQLite export plugin for MySQL Workbench
-- Copyright (C) 2009 created by Thomas Henlich - http://www.henlich.de/
-- Copyright (C) 2013 modified by Tony Beltramelli - http://www.tonybeltramelli.com/
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- this function is called first by MySQL Workbench core to determine number of plugins in this module and basic plugin info
-- see the comments in the function body and adjust the parameters as appropriate
--

function getModuleInfo()
  return {
    name= "ExportSQLite",
    author= "Thomas Henlich, Tony Beltramelli",
    version= "2013.08.05",
    implements= "PluginInterface",
    functions= {
      "getPluginInfo:l<o@app.Plugin>:",
      "exportSQLite:i:o@db.Catalog"
    }
  }
end

function objectPluginInput(type)
  return grtV.newObj("app.PluginObjectInput", {objectStructName= type})
end

function getPluginInfo()
    local l
    local plugin

    -- create the list of plugins that this module exports
    l = grtV.newList("object", "app.Plugin")

    -- create a new app.Plugin object for every plugin
    plugin = grtV.newObj("app.Plugin", {
      name= "wb.catalog.util.exportSQLite",
      caption= "Export SQLite CREATE script",
      moduleName= "ExportSQLite",
      pluginType= "normal",
      moduleFunctionName= "exportSQLite",
      inputValues= {objectPluginInput("db.Catalog")},
      rating= 100,
      showProgress= 0,
      groups= {"Catalog/Utilities", "Menu/Utilities"}
    })

    -- fixup owner
    plugin.inputValues[1].owner = plugin
  
    -- add to the list of plugins
    grtV.insert(l, plugin)
  
    return l
end

-- check uniqueness of schema, table and index names
-- return 0 on success
-- otherwise return 1 (the export process should abort)
function validateForSQLiteExport(obj)
  local id, i, j, errName, haveErrors, schema, tbl, column, index
  id = {}
  for i = 1, grtV.getn(obj.schemata) do
    schema = obj.schemata[i]
    if (id[schema.name]) then
      haveErrors = 1
      if (Workbench:confirm("Name conflict", "Schemas " .. id[schema.name] .. " and " .. i .. " have the same name \"" .. schema.name .. "\". Please rename one of them.\nSearch for more such errors?") == 0) then
        return 1
      end

    else
      id[schema.name] = i
    end
  end

  -- do not continue looking for errors on schema name error
  if (haveErrors) then
    return 1
  end

  for i = 1, grtV.getn(obj.schemata) do
    schema = obj.schemata[i]
    id = {}
    for j = 1, grtV.getn(schema.tables) do
      tbl = schema.tables[j]
      if (tbl.name == "") then
        haveErrors = 1
        if (Workbench:confirm("Name conflict", "Table " .. j .. " in schema \"" .. schema.name .. "\" has no name. Please rename.\nSearch for more such errors?") == 0) then
          return 1
        end
      end
      if (id[tbl.name]) then
        haveErrors = 1
        if (Workbench:confirm("Name conflict", "Tables " .. id[tbl.name] .. " and " .. j .. " in schema \"" .. schema.name .. "\" have the same name \"" .. tbl.name .. "\". Please rename one of them.\nSearch for more such errors?") == 0) then
          return 1
        end

      else
        id[tbl.name] = j
      end
      
    end
  end
  
  if (haveErrors) then
    return 1
  end
  
  for i = 1, grtV.getn(obj.schemata) do
    schema = obj.schemata[i]
    for j = 1, grtV.getn(schema.tables) do
      tbl = schema.tables[j]
      id = {}
      for k = 1, grtV.getn(tbl.columns) do
        column = tbl.columns[k]
        if (column.name == "") then
          haveErrors = 1
          if (Workbench:confirm("Name conflict", "Column " .. k .. " in table \"" .. schema.name .. "\".\"" .. tbl.name .. "\" has no name. Please rename.\nSearch for more such errors?") == 0) then
            return 1
          end
        end
        if (id[column.name]) then
          haveErrors = 1
          if (Workbench:confirm("Name conflict", "Columns " .. id[column.name] .. " and " .. k .. " in table \"" .. schema.name .. "\".\"" .. tbl.name .. "\" have the same name \"" .. column.name .. "\". Please rename one of them.\nSearch for more such errors?") == 0) then
            return 1
          end

        else
          id[column.name] = k
        end
      end
      
      -- now check indices (except primary/unique)
      id = {}
      for k = 1, grtV.getn(tbl.indices) do
        index = tbl.indices[k]
        if (index.indexType == "INDEX") then
          if (index.name == "") then
            haveErrors = 1
            if (Workbench:confirm("Name conflict", "Index " .. k .. " in table \"" .. schema.name .. "\".\"" .. tbl.name .. "\" has no name. Please rename.\nSearch for more such errors?") == 0) then
              return 1
            end
          end
          if (id[index.name]) then
            haveErrors = 1
            if (Workbench:confirm("Name conflict", "Indices " .. id[index.name] .. " and " .. k .. " in table \"" .. schema.name .. "\".\"" .. tbl.name .. "\" have the same name \"" .. index.name .. "\". Please rename one of them.\nSearch for more such errors?") == 0) then
              return 1
            end

          else
            id[index.name] = k
          end
        end
      end
    end
  end
  
  if (haveErrors) then
    return 1
  end
  
  return 0    
end

-- hack: if comment starts with "Defer..." we make it a deferred FK
-- could use member 'deferability' (WB has it), but there is no GUI for it
function isDeferred(fKey)
  return (trim(fKey.comment):sub(1, 5):lower() == "defer")
end

function exportTable(file, dbName, schema, tbl)
  local primaryKey, pKColumn, colComment
  -- cannot create empty tables
  if (grtV.getn(tbl.columns) > 0) then
  	file:write("DROP TABLE IF EXISTS " .. dbName .. dq(tbl.name) .. ";\n\n")
    file:write("CREATE TABLE IF NOT EXISTS " .. dbName .. dq(tbl.name) .. "(\n" .. sCommentFormat(tbl.comment))

    -- find the primary key
    for k = 1, grtV.getn(tbl.indices) do
      local index
      index = tbl.indices[k]
      if (index.isPrimary == 1) then
        primaryKey = index
        break
      end
    end
    
    -- is primary key single-column?
    if (primaryKey and (grtV.getn(primaryKey.columns) == 1)) then
      pKColumn = primaryKey.columns[1].referencedColumn
    end
    
    colComment = ""
    for k = 1, grtV.getn(tbl.columns) do
      local column, sqLiteType, length, check, flags
      check = ""
      column = tbl.columns[k]
      if (column.simpleType) then
        sqLiteType = column.simpleType.name
        flags = column.simpleType.flags
      else
        sqLiteType = column.userType.name
        flags = column.flags
      end
      length = column.length
      -- for INTEGER PRIMARY KEY column to become an alias for the rowid
      -- the type needs to be "INTEGER" not "INT"
      -- we fix it for other columns as well
      if (sqLiteType:find("INT") or sqLiteType == "LONG") then
        sqLiteType = "INTEGER"
        length = -1
        -- check flags for "unsigned"
        for f = 1, grtV.getn(column.flags) do
          if (grtV.toLua(column.flags[f]) == "UNSIGNED") then
            check = dq(column.name) .. ">=0"
            break
          end
        end
      end
      -- we even implement ENUM (because we can)
      if (sqLiteType == "ENUM") then
        sqLiteType = "TEXT"
        if (column.datatypeExplicitParams) then
          check = dq(column.name) .. " IN" .. column.datatypeExplicitParams
        end
      end
      if (k > 1) then
        file:write("," .. commentFormat(colComment) .. "\n")
      end
      file:write("  " .. dq(column.name))
      -- type is optional in SQLite
      if (sqLiteType ~= "") then
        file:write(" " .. sqLiteType)
      end
      -- for [VAR]CHAR and such types specify length
      -- even though this is not used in SQLite
      if (length > 0) then
        file:write("(" .. length .. ")")
      end

      -- Must specify single-column PKs as column-constraints
      -- for AI/rowid behaviour
      if (column == pKColumn) then
        file:write(" PRIMARY KEY")
        if (primaryKey.columns[1].descend == 1) then
          file:write(" DESC")
        end
        -- only PK columns can be AI in SQLite
        if (column.autoIncrement == 1) then
          file:write(" AUTOINCREMENT")
        end
      end
      -- check for NotNull
      if (column.isNotNull == 1) then
        file:write(" NOT NULL")
      end
      
      if (check ~= "") then
        file:write(" CHECK(" .. check .. ")")
      end
      
      if (column.defaultValue ~= "") then
        file:write(" DEFAULT " .. column.defaultValue)
      end

      colComment = column.comment
    end
    
    -- for multicolumn PKs
    if (primaryKey and not pKColumn) then
      file:write("," .. commentFormat(colComment) .. "\n  PRIMARY KEY(" .. printIndexColumns(primaryKey) .. ")")
      colComment = ""
    end
    
    -- put non-primary, UNIQUE Keys in CREATE TABLE as well (because we can)
    for k = 1, grtV.getn(tbl.indices) do
      local index
      index = tbl.indices[k]
      if (index ~= primaryKey and index.indexType == "UNIQUE") then
        file:write("," .. commentFormat(colComment) .. "\n")
        colComment = ""
        if (index.name ~= "") then
          file:write("  CONSTRAINT " .. dq(index.name) .. "\n  ")
        end
        file:write("  UNIQUE(" .. printIndexColumns(index) .. ")")
      end
    end
    
    for k = 1, grtV.getn(tbl.foreignKeys) do
      local fKey
      fKey = tbl.foreignKeys[k]
      haveFKeys = 1
      file:write("," .. commentFormat(colComment) .. "\n")
      colComment = ""
      if (fKey.name ~= "") then
        file:write("  CONSTRAINT " .. dq(fKey.name) .. "\n  ")
      end
      file:write("  FOREIGN KEY(" .. printFKColumns(fKey.columns) .. ")\n")
      file:write("    REFERENCES " .. dq(fKey.referencedTable.name) .. "(" .. printFKColumns(fKey.referencedColumns) .. ")")
      if (fKey.deleteRule == "RESTRICT" or fKey.deleteRule == "CASCADE" or fKey.deleteRule == "SET NULL") then
        file:write("\n    ON DELETE " .. fKey.deleteRule)
      end
      if (fKey.updateRule == "RESTRICT" or fKey.updateRule == "CASCADE" or fKey.updateRule == "SET NULL") then
        file:write("\n    ON UPDATE " .. fKey.updateRule)
      end
      if (isDeferred(fKey)) then
        file:write(" DEFERRABLE INITIALLY DEFERRED")
      end
    end
    
    file:write(commentFormat(colComment) .. "\n);\n")
    if(grtV.getn(tbl.indices) <= 1) then
    	file:write("\n")
    end
    
    -- CREATE INDEX statements for
    -- all non-primary, non-unique, non-foreign indexes 
    for k = 1, grtV.getn(tbl.indices) do
      local index, indexName
      index = tbl.indices[k]
      if (index.indexType == "INDEX") then
        indexName = tbl.name .. "." .. index.name
        if (index.name == "") then
          indexName = tbl.name .. ".index" .. k
          --uniqueId = uniqueId + 1
        end
        file:write("CREATE INDEX " .. dbName .. dq(indexName) .. " ON " .. dq(tbl.name) .. "(")
        file:write(printIndexColumns(index) .. ");\n")
        if (k == grtV.getn(tbl.indices)) then
        	file:write("\n")
        end        
      end
    end

    -- write the INSERTS (currently always)
    local tableInserts
    if (type(tbl.inserts) == "string") then
      -- old inserts, WB 5.1-
      tableInserts = tbl.inserts
    else
      -- new inserts, WB 5.2.10+
      tableInserts = tbl:inserts()
    end
    for insert in string.gmatch(tableInserts, "[^\r\n]+") do
      local columnsValues
      -- WB 5.1- insert
      local insertStart = "insert into `" .. tbl.name .. "` ("
      if (insert:sub(1, insertStart:len()):lower() == insertStart) then
        columnsValues = insert:sub(insertStart:len() + 1)
      else
        -- WB 5.2+ insert
        insertStart = "insert into `" .. schema.name .. "`.`" .. tbl.name .. "` ("
        if (insert:sub(1, insertStart:len()):lower() == insertStart) then
          columnsValues = insert:sub(insertStart:len() + 1)
          else
            Workbench:confirm("Error", "Unrecognized command in insert")
            return 1
        end
      end
      local lastColumn = 0
      for k = 1, grtV.getn(tbl.columns) do
        columnName = "`" .. tbl.columns[k].name .. "`"
        if (columnsValues:sub(1, columnName:len()) == columnName) then
          columnsValues = columnsValues:sub(columnName:len() + 1)
          if (columnsValues:sub(1, 1) == ")") then
            columnsValues = columnsValues:sub(2)
            lastColumn = k
            break
          else
            if (columnsValues:sub(1, 2) == ", ") then
              columnsValues = columnsValues:sub(3)
            else
              Workbench:confirm("Error", "Unrecognized character in column list")
            end
          end
        else
          Workbench:confirm("Error", "Unrecognized column in inserts")
          return 1
        end
      end
      file:write("INSERT INTO " .. dq(tbl.name) .. "(")
      for k = 1, lastColumn do
        if (k > 1) then
          file:write(",")
        end
        file:write(dq(tbl.columns[k].name))
      end
      
      if (columnsValues:sub(1, 9):lower() ~= " values (") then
        Workbench:confirm("Error", "Unrecognized SQL in insert")
        return 1
      end
      columnsValues = columnsValues:sub(10)

      file:write(") VALUES(")
      file:write(tostring(columnsValues:gsub("\\(.)",
        function(c)
          if (c == "'") then
            return "''"
          else
            return c
          end
        end)))
      file:write("\n")
    end
  end
  return 0
end

function orderTables(file, dbName, schema, unOrdered, respectDeferredness)
  repeat
    local haveOrdered = false

    for j = 1, grtV.getn(schema.tables) do
      local tbl = schema.tables[j]
      if (unOrdered[tbl.name]) then
        local hasForwardReference = false
        for k = 1, grtV.getn(tbl.foreignKeys) do
          local fKey
          fKey = tbl.foreignKeys[k]
          if (unOrdered[fKey.referencedTable.name] and fKey.referencedTable.name ~= tbl.name
            and not(respectDeferredness and isDeferred(fKey))) then
            hasForwardReference = true
            break
          end
        end
        if (not hasForwardReference) then
          if (exportTable(file, dbName, schema, tbl) ~= 0) then
            print("Error writing table " .. tbl.name .. "\n")
            return 1
          end
          unOrdered[tbl.name] = nil 
          haveOrdered = true
        end
      end
    end
  until (not haveOrdered)
  return 0
end

function exportSchema(file, schema, isMainSchema)
  print("Schema " .. schema.name .. " has " .. grtV.getn(schema.tables) .. " tables\n")
  if (grtV.getn(schema.tables) > 0) then
    file:write("\n-- Schema: " .. schema.name .. "\n")
    file:write(sCommentFormat(schema.comment))

    if (isMainSchema) then
      dbName = ""
    else
      dbName = dq(schema.name) .. "."
      file:write('ATTACH "' .. safeFileName(schema.name .. ".sdb") .. '" AS ' .. dq(schema.name) .. ';\n')
    end
    file:write("BEGIN;\n\n")

    -- find a valid table order for inserts from FK constraints
    local unOrdered = {}
    for j = 1, grtV.getn(schema.tables) do
      local tbl = schema.tables[j]
      unOrdered[tbl.name] = tbl
    end
    
    -- try treating deferred keys like non-deferred keys first for ordering
    if (orderTables(file, dbName, schema, unOrdered, false) ~= 0) then
      print("Error ordering tables in schema " .. schema.name .. "\n")
      return 1
    end
    -- now try harder (leave out deferred keys from determining an order)
    if (orderTables(file, dbName, schema, unOrdered, true) ~= 0) then
      print("Error ordering tables in schema " .. schema.name .. "\n")
      return 1
    end
   
    -- loop through all remaining tables, if any. Have circular FK refs. How to handle?
    for j = 1, grtV.getn(schema.tables) do
      local tbl = schema.tables[j]
      if (unOrdered[tbl.name]) then
        if (exportTable(file, dbName, schema, tbl) ~= 0) then
          print("Error writing table " .. tbl.name .. "\n")
          return 1
        end
      end
    end
    file:write("COMMIT;\n")
  end
  return 0
end

-- function to go through all schemata in catalog and rename all FKs of table-objects
function exportSQLite(obj)
  
  local i, j, k, f, schema, tbl, path, file, dbName, info, uniqueId, haveFKeys
  local version, versionNumber
  
  haveFKeys = 0
  
  version = grtV.getGlobal("/wb/info/version")
  versionNumber = version.majorNumber .. "." .. version.minorNumber .. "." .. version.releaseNumber
  if (validateForSQLiteExport(obj) ~= 0) then
    return 1
  end

    -- we don't have requestFileSave in <= 5.1
  if (Workbench.requestFileSave) then
    path = Workbench:requestFileSave("Save as", "SQL Files (*.sql)|*.sql")
  else
    path = Workbench:input("Save as")
  end
  if (path == "") then
    return 1
  end
  file = io.open(path, "w+")
  if (file == nil) then
    Workbench:confirm("Error", "Cannot open file")
    return 1
  end
  
--  if (not path:find("\.sql$")) then
    -- truncate db file
--    file:close()
--    file = io.popen("sqlite3 -batch -bail " .. path, "w")
--  end
  
  info = grtV.getGlobal("/wb/doc/info")
  file:write(infoFormat("Creator", "MySQL Workbench " .. versionNumber .. "/ExportSQLite plugin " .. getModuleInfo().version))
  file:write(infoFormat("Author", info.author))
  file:write(infoFormat("Caption", info.caption))
  file:write(infoFormat("Project", info.project))
  file:write(infoFormat("Changed", info.dateChanged))
  file:write(infoFormat("Created", info.dateCreated))
  file:write(infoFormat("Description", info.description))

  file:write("PRAGMA foreign_keys = OFF;\n")
  -- loop over all catalogs in schema, find main schema
  -- main schema is first nonempty schema or nonempty schema named "main"
  local iMain = -1
  for i = 1, grtV.getn(obj.schemata) do
    local schema = obj.schemata[i]
    if (grtV.getn(schema.tables) > 0) then
      if (iMain < 0) then
        iMain = i
      end
      if (schema.name == "main") then
        iMain = i
        break
      end      
    end
    schema = obj.schemata[i]
  end
  
  if (iMain > 0) then
    if (exportSchema(file, obj.schemata[iMain], true) ~= 0) then
      print("Error writing schema " .. obj.schemata[iMain].name .. "\n")
      return 1
    end
  end

  for i = 1, grtV.getn(obj.schemata) do
    uniqueId = 1
    if (i ~= iMain) then
      if (exportSchema(file, obj.schemata[i], false) ~= 0) then
        print("Error writing schema " .. obj.schemata[i].name .. "\n")
        return 1
      end
    end
  end
    
  file:close()
  print("Export to " .. path .. " finished.\n")
  return 0
end

-- get comma separated column list of an index
function printIndexColumns(index)
  local i, s
  s = ""
  for i = 1, grtV.getn(index.columns) do
    local column, refColumn
    column = index.columns[i]
    if (i > 1) then
      s = s .. ","
    end
    s = s .. dq(column.referencedColumn.name)
    if (column.descend == 1) then
      s = s .. " DESC"
    end
  end
  return s
end

-- get comma separated column/reference list of a foreign key
function printFKColumns(columns)
  local i, s
  s = ""
  for i = 1, grtV.getn(columns) do
    if (i > 1) then
      s = s .. ","
    end
    s = s .. dq(columns[i].name)
  end
  return s
end

-- get comma separated referenced column list of a foreign key
function printFKRefdColumns(fKey)
  local i, s
  s = ""
  for i = 1, grtV.getn(fKey.columns) do
    if (i > 1) then
      s = s .. ", "
    end
    s = s .. dq(fKey.columns[i].referencedColumn.name)
  end
  return s
end

-- double quote identifer, replacing " by ""
function dq(id)
  return '"' .. id:gsub('"', '""') .. '"'
end

-- create safe filename from identifer
function safeFileName(id)
  return id:gsub(
    '[/\\:%*%?"<>|%%]',
    function(c) return string.format("%%%02x", string.byte(c)) end
  )
end

-- remove trailing and leading whitespace from string.
function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- format a info field as SQL comment
function infoFormat(header, body)
  local strippedBody
  strippedBody = trim(body)
  if (strippedBody == "") then
    return ""
  elseif (strippedBody:find("\n")) then
  -- multiline comment
    return string.format("-- %s:\n--   %s\n", header,
      strippedBody:gsub("\n","\n--   "))
  else
  -- single line
    return string.format("-- %-14s %s\n", header..":", strippedBody)
  end
end

-- format a schema or table comment as SQL comment
-- table comments to be stored in SQLite schema
function sCommentFormat(body)
  local strippedBody
  strippedBody = trim(body)
  if (strippedBody == "") then
    return ""
  else
  -- multiline comment
    return string.format("--   %s\n",
      strippedBody:gsub("\n","\n--   "))
  end
end

-- format a column comment as SQL comment
-- to be stored in SQLite schema for user information
function commentFormat(body)
  local strippedBody
  strippedBody = trim(body)
  if (strippedBody == "") then
    return ""
  elseif (strippedBody:find("\n")) then
  -- multiline comment
    return string.format("\n--   %s",
      strippedBody:gsub("\n","\n--   "))
  else
  -- single line
    return string.format("-- %s", strippedBody)
  end
end
