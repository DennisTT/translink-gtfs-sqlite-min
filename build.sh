#!/bin/bash

FEED_URL="http://mapexport.translink.bc.ca/current/google_transit.zip"
FEED_FOLDER="feed"
OUTPUT_DB="translink_gtfs.db"
OUTPUT_DB_VACUUMED="translink_gtfs_small.db"
OUTPUT_DB_VACUUMED_COMPRESSED="translink_gtfs_small.db.zip"
SQL_STRUCTURE="libs/import/src/gtfs_tables.sqlite"
SQL_VACUUMER="libs/import/src/vacuumer.sqlite"
SQL_CUSTOM_VACUUMER="sql/translink_vacuumer.sqlite"

echo "Starting"

echo -n "Getting data..."
if [ ! -d $FEED_FOLDER ]; then
	mkdir $FEED_FOLDER
	curl $FEED_URL > $FEED_FOLDER/latest.zip
	unzip -d $FEED_FOLDER $FEED_FOLDER/latest.zip
    echo "done"
else
    echo "already exists"
fi

echo -n "Generating SQLite database..."
if [ ! -f $OUTPUT_DB ]; then
    cat $SQL_STRUCTURE \
        <(python libs/import/src/import_gtfs_to_sql.py $FEED_FOLDER/ nocopy) \
            | sqlite3 $OUTPUT_DB
    echo "done"
else
    echo "already exists"
fi

echo -n "Vacuuming extraneous data..."
rm $OUTPUT_DB_VACUUMED
cp $OUTPUT_DB $OUTPUT_DB_VACUUMED
cat $SQL_CUSTOM_VACUUMER | sqlite3 $OUTPUT_DB_VACUUMED
echo "done"

echo -n "General vacuum..."
cat $SQL_VACUUMER | sqlite3 $OUTPUT_DB_VACUUMED
echo "done"

echo -n "Compressing database"
rm $OUTPUT_DB_VACUUMED_COMPRESSED
zip -9 -j $OUTPUT_DB_VACUUMED_COMPRESSED $OUTPUT_DB_VACUUMED
echo "done"

echo "All done!"