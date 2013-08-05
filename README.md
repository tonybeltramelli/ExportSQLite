#Export-SQLite
======================

ExportSQLite is a plugin to export SQLite files from the MySQLWorkbench software.  
I modified the script initially written by Thomas Henlich - http://www.henlich.de/  

The generated SQLite file can be used directly into your iOS or Android project.

##Usage

 * From MySQLWorkbench, go to "Scripting -> Install Plugin/Module…";
 * From the dialog box, select the ExportSQLite.grt.lua script;
 * Restart MySQLWorkbench;
 * To generate your SQLite file, open your model and go to "Plugins -> Utilities -> Export SQLite CREATE script";
 * Type a file name and hit save;
 * Enjoy your SQLite file;

##Generated file example

SQL file generated with MySQLWorkbench

```sql
DROP TABLE IF EXISTS `database`.`table` ;

CREATE  TABLE IF NOT EXISTS `database`.`table` (
  `id_table` INT NOT NULL ,
  `value_table` DECIMAL(10,0) NULL ,
  `time_table` TIME NULL ,
  `description_table` TEXT NULL ,
  `friend_id_friend` INT NOT NULL ,
  `type_id_type` INT NOT NULL ,
  `location_id_location` INT NOT NULL ,
  PRIMARY KEY (`id_table`) ,
  INDEX `fk_table_friend1` (`friend_id_friend` ASC) ,
  INDEX `fk_table_type1` (`type_id_type` ASC) ,
  INDEX `fk_table_location1` (`location_id_location` ASC) ,
  CONSTRAINT `fk_table_friend1`
    FOREIGN KEY (`friend_id_friend` )
    REFERENCES `database`.`friend` (`id_friend` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_table_type1`
    FOREIGN KEY (`type_id_type` )
    REFERENCES `database`.`type` (`id_type` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_table_location1`
    FOREIGN KEY (`location_id_location` )
    REFERENCES `database`.`location` (`id_location` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;
```

SQLite file generated with MySQLWorkbench and the ExportSQLite plugin

```sql
DROP TABLE IF EXISTS "table";

CREATE TABLE IF NOT EXISTS "table"(
  "id_table" INTEGER PRIMARY KEY NOT NULL,
  "value_table" NUMERIC,
  "time_table" TIME,
  "description_table" TEXT,
  "friend_id_friend" INTEGER NOT NULL,
  "type_id_type" INTEGER NOT NULL,
  "location_id_location" INTEGER NOT NULL,
  CONSTRAINT "fk_table_friend1"
    FOREIGN KEY("friend_id_friend")
    REFERENCES "friend"("id_friend"),
  CONSTRAINT "fk_table_type1"
    FOREIGN KEY("type_id_type")
    REFERENCES "type"("id_type"),
  CONSTRAINT "fk_table_location1"
    FOREIGN KEY("location_id_location")
    REFERENCES "location"("id_location")
);
CREATE INDEX "table.fk_table_friend1" ON "table"("friend_id_friend");
CREATE INDEX "table.fk_table_type1" ON "table"("type_id_type");
CREATE INDEX "table.fk_table_location1" ON "table"("location_id_location");
```

Have fun !
@Tbeltramelli <http://twitter.com/#!/tbeltramelli/>