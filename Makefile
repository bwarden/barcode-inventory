all:

%.sql: data/%.db
	sqlite3 $< .schema > $@
