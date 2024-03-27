CREATE OR ALTER PROCEDURE GenerateOHE
    @TableName NVARCHAR(128)
AS
BEGIN
    DECLARE @DynamicSQL NVARCHAR(MAX),
            @ColumnName NVARCHAR(256),
            @Value NVARCHAR(MAX),
            @SchemaName NVARCHAR(128),
            @SqlPart NVARCHAR(MAX);


    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = @TableName)
    BEGIN
        PRINT 'Table does not exist.';
        RETURN;
    END

    SELECT @SchemaName = TABLE_SCHEMA
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME = @TableName;


    SET @DynamicSQL = N'SELECT ';


    SELECT @DynamicSQL += QUOTENAME(COLUMN_NAME) + ', '
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @TableName
    AND TABLE_SCHEMA = @SchemaName
    AND DATA_TYPE IN ('int', 'decimal', 'numeric', 'float', 'double', 'real', 'bit', 'tinyint', 'smallint', 'mediumint', 'bigint');

    SET @DynamicSQL = LEFT(@DynamicSQL, LEN(@DynamicSQL) - 1);

    IF OBJECT_ID('tempdb..#DistinctValues') IS NOT NULL DROP TABLE #DistinctValues;
    CREATE TABLE #DistinctValues (Value NVARCHAR(MAX));

    DECLARE ColumnCursor CURSOR FOR 
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = @TableName 
        AND TABLE_SCHEMA = @SchemaName
        AND DATA_TYPE NOT IN ('int', 'decimal', 'numeric', 'float', 'double', 'real', 'bit', 'tinyint', 'smallint', 'mediumint', 'bigint');

    OPEN ColumnCursor;
    FETCH NEXT FROM ColumnCursor INTO @ColumnName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SqlPart = '';

        DECLARE @ValuesSQL NVARCHAR(MAX) = 'SELECT DISTINCT [' + @ColumnName + N'] FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName);

        INSERT INTO #DistinctValues(Value)
        EXEC sp_executesql @ValuesSQL;

        DECLARE ValueCursor CURSOR FOR SELECT Value FROM #DistinctValues;
        OPEN ValueCursor;
        FETCH NEXT FROM ValueCursor INTO @Value;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @SqlPart += ', CASE WHEN [' + @ColumnName + '] = ''' + REPLACE(@Value, '''', '''''') + ''' THEN 1 ELSE 0 END AS [' + @ColumnName + '_' + REPLACE(REPLACE(REPLACE(@Value, ' ', '_'), '''', ''), ',', '') + ']';
            FETCH NEXT FROM ValueCursor INTO @Value;
        END

        CLOSE ValueCursor;
        DEALLOCATE ValueCursor;
        TRUNCATE TABLE #DistinctValues;

        SET @DynamicSQL += @SqlPart;
        FETCH NEXT FROM ColumnCursor INTO @ColumnName;
    END

    CLOSE ColumnCursor;
    DEALLOCATE ColumnCursor;

    SET @DynamicSQL +=  N' FROM ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName);
    --SET @DynamicSQL = N'SELECT * INTO ##OHEResults FROM (' + @DynamicSQL + N') AS DerivedTable'; - to dla tymczasowej na inne operacje

    EXEC sp_executesql @DynamicSQL;
END;
GO

EXEC GenerateOHE @TableName = 'dane_pojazdow1';
