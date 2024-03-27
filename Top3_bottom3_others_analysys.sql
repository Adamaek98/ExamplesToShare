CREATE OR ALTER PROCEDURE GenerateCategoryAnalysis
    @TableName NVARCHAR(128)
BEGIN
    DECLARE @DynamicSQL NVARCHAR(MAX);
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @FullTableName NVARCHAR(256);

    SELECT TOP 1 @SchemaName = TABLE_SCHEMA, @FullTableName = QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME = @TableName;

    IF @SchemaName IS NULL
    BEGIN
        RAISERROR('Table not found in the database.', 16, 1);
        RETURN;
    END

    SET @DynamicSQL = N'WITH CategoryData AS (';

    DECLARE @ColumnName NVARCHAR(256);
    DECLARE @FirstColumn BIT = 1;

    DECLARE CategoryCursor CURSOR FOR
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = @TableName
          AND TABLE_SCHEMA = @SchemaName
          AND DATA_TYPE IN ('varchar', 'char', 'text', 'nvarchar', 'nchar');

    OPEN CategoryCursor;
    FETCH NEXT FROM CategoryCursor INTO @ColumnName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @FirstColumn = 1
            SET @FirstColumn = 0; 
        ELSE
            SET @DynamicSQL += N' UNION ALL '; 

        SET @DynamicSQL += N'SELECT ''' + @ColumnName + ''' AS CategoryType, ' + QUOTENAME(@ColumnName) + ' AS CategoryValue, COUNT(*) AS LiczbaWystapien FROM ' + @FullTableName + ' GROUP BY ' + QUOTENAME(@ColumnName);

        FETCH NEXT FROM CategoryCursor INTO @ColumnName;
    END

    CLOSE CategoryCursor;
    DEALLOCATE CategoryCursor;

    SET @DynamicSQL += N') 
    , RankedData AS (
        SELECT CategoryType, CategoryValue, LiczbaWystapien,
               ROW_NUMBER() OVER(PARTITION BY CategoryType ORDER BY LiczbaWystapien DESC) AS TopRank,
               ROW_NUMBER() OVER(PARTITION BY CategoryType ORDER BY LiczbaWystapien ASC) AS BottomRank
        FROM CategoryData
    )
    , CTE_Aggregated AS (
        SELECT
            CategoryType,
            CASE
                WHEN TopRank <= 3 THEN CategoryValue
                WHEN BottomRank <= 3 THEN CategoryValue
                ELSE CategoryType + ''_others''
            END AS CategoryGroup,
            SUM(LiczbaWystapien) AS Total
        FROM RankedData
        GROUP BY CategoryType,
            CASE
                WHEN TopRank <= 3 THEN CategoryValue
                WHEN BottomRank <= 3 THEN CategoryValue
                ELSE CategoryType + ''_others''
            END
    )
    SELECT CategoryType, CategoryGroup, SUM(Total) AS Total
    FROM CTE_Aggregated
    GROUP BY CategoryType, CategoryGroup
    ORDER BY CategoryType, SUM(Total) DESC;';

    PRINT @DynamicSQL;
    EXEC sp_executesql 
    @DynamicSQL, 
    N'@SchemaName NVARCHAR(128), @FullTableName NVARCHAR(256)', 
    @SchemaName, 
    @FullTableName;

END;
GO
EXEC GenerateCategoryAnalysis @TableName = 'dane_pojazdow1';
