set hive.explain.user=false;
SET hive.vectorized.execution.enabled=true;
SET hive.vectorized.execution.reduce.enabled=true;
set hive.fetch.task.conversion=none;
set hive.cli.print.header=true;

-- SORT_QUERY_RESULTS

-- In this test, 2 files are loaded into table T1. The data contains rows with the same value of a and b,
-- with different number of rows for a and b in each file. Since bucketizedHiveInputFormat is used,
-- this tests that the aggregate function stores the partial aggregate state correctly even if an
-- additional MR job is created for processing the grouping sets.
CREATE TABLE T1_text(a STRING, b STRING, c STRING) ROW FORMAT DELIMITED FIELDS TERMINATED BY ' ' STORED AS TEXTFILE;

LOAD DATA LOCAL INPATH '../../data/files/grouping_sets1.txt' INTO TABLE T1_text;
LOAD DATA LOCAL INPATH '../../data/files/grouping_sets2.txt' INTO TABLE T1_text;

CREATE TABLE T1 STORED AS ORC AS SELECT * FROM T1_text;

set hive.input.format = org.apache.hadoop.hive.ql.io.BucketizedHiveInputFormat;
set hive.new.job.grouping.set.cardinality = 30;

-- The query below will execute in a single MR job, since 4 rows are generated per input row
-- (cube of a,b will lead to (a,b), (a, null), (null, b) and (null, null) and
-- hive.new.job.grouping.set.cardinality is more than 4.
EXPLAIN VECTORIZATION DETAIL
SELECT a, b, avg(c), count(*) from T1 group by a, b with cube;

EXPLAIN VECTORIZATION DETAIL
SELECT a, b, avg(c), count(*) from T1 group by cube(a, b);
SELECT a, b, avg(c), count(*) from T1 group by a, b with cube;

set hive.new.job.grouping.set.cardinality=2;

-- The query below will execute in 2 MR jobs, since hive.new.job.grouping.set.cardinality is set to 2.
-- The partial aggregation state should be maintained correctly across MR jobs.
EXPLAIN VECTORIZATION DETAIL
SELECT a, b, avg(c), count(*) from T1 group by a, b with cube;
SELECT a, b, avg(c), count(*) from T1 group by a, b with cube;

