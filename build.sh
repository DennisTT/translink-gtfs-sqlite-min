#!/bin/bash

FEED_URL="http://ns.translink.ca/gtfs/google_transit.zip"
FEED_FOLDER="feed"
OUTPUT_SQL="translink_gtfs.sql"
OUTPUT_DB="translink_gtfs.db"
OUTPUT_DB_VACUUMED="translink_gtfs_small.db"
OUTPUT_DB_VACUUMED_COMPRESSED="translink_gtfs_small.db.zip"
SQL_STRUCTURE="libs/import/src/gtfs_tables.sqlite"
SQL_VACUUMER="libs/import/src/vacuumer.sqlite"
SQL_CUSTOM_VACUUMER="sql/translink_vacuumer.sqlite"

if [ "$1" == "clean" ]; then
	rm -rf $FEED_FOLDER $OUTPUT_SQL $OUTPUT_DB $OUTPUT_DB_VACUUMED $OUTPUT_DB_VACUUMED_COMPRESSED
	echo "cleaned"
	exit 0
fi

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

echo -n "Cleaning BOM"
for f in $FEED_FOLDER/*.txt
do
	vi -s setnobomb.vimscript $f
done
echo "done"

echo -n "Generating SQL..."
if [ ! -f $OUTPUT_SQL ]; then
    python libs/import/src/import_gtfs_to_sql.py $FEED_FOLDER/ nocopy > $OUTPUT_SQL
    echo "done"
else
    echo "already exists"
fi

echo -n "Creating new SQLite database..."
if [ ! -f $OUTPUT_DB ]; then
    cat $SQL_STRUCTURE $OUTPUT_SQL | sqlite3 $OUTPUT_DB
    echo "done"
else
    echo "already exists"
fi

echo -n "Vacuuming extraneous data..."
rm $OUTPUT_DB_VACUUMED > /dev/null
cp $OUTPUT_DB $OUTPUT_DB_VACUUMED
cat $SQL_CUSTOM_VACUUMER | sqlite3 $OUTPUT_DB_VACUUMED
echo "done"

echo -n "General vacuum..."
cat $SQL_VACUUMER | sqlite3 $OUTPUT_DB_VACUUMED
echo "done"

echo -n "Compressing database"
rm $OUTPUT_DB_VACUUMED_COMPRESSED > /dev/null
zip -9 -j $OUTPUT_DB_VACUUMED_COMPRESSED $OUTPUT_DB_VACUUMED
echo "done"

echo "All done!"
