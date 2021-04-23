
DROP PROCEDURE IF EXISTS SEDdatabase_nameSED.drop_user_if_exists ;
DELIMITER $$
CREATE PROCEDURE SEDdatabase_nameSED.drop_user_if_exists()
BEGIN
  DECLARE foo BIGINT DEFAULT 0 ;
  SELECT COUNT(*)
  INTO foo
    FROM mysql.user
      WHERE User = 'SEDDBUSR_adminrwSED' and  Host = '%';
   IF foo > 0 THEN
         DROP USER 'SEDDBUSR_adminrwSED'@'%' ;
  END IF;
END ;$$
DELIMITER ;
CALL SEDdatabase_nameSED.drop_user_if_exists() ;
DROP PROCEDURE IF EXISTS SEDdatabase_nameSED.drop_users_if_exists ;


DROP PROCEDURE IF EXISTS SEDdatabase_nameSED.drop_user_if_exists ;
DELIMITER $$
CREATE PROCEDURE SEDdatabase_nameSED.drop_user_if_exists()
BEGIN
  DECLARE foo BIGINT DEFAULT 0 ;
  SELECT COUNT(*)
  INTO foo
    FROM mysql.user
      WHERE User = 'SEDDBUSR_webphprwSED' and  Host = '%';
   IF foo > 0 THEN
         DROP USER 'SEDDBUSR_webphprwSED'@'%' ;
  END IF;
END ;$$
DELIMITER ;
CALL SEDdatabase_nameSED.drop_user_if_exists() ;
DROP PROCEDURE IF EXISTS SEDdatabase_nameSED.drop_users_if_exists ;

DROP PROCEDURE IF EXISTS SEDdatabase_nameSED.drop_user_if_exists ;
DELIMITER $$
CREATE PROCEDURE SEDdatabase_nameSED.drop_user_if_exists()
BEGIN
  DECLARE foo BIGINT DEFAULT 0 ;
  SELECT COUNT(*)
  INTO foo
    FROM mysql.user
      WHERE User = 'SEDDBUSR_javamailSED' and  Host = '%';
   IF foo > 0 THEN
         DROP USER 'SEDDBUSR_javamailSED'@'%' ;
  END IF;
END ;$$
DELIMITER ;
CALL SEDdatabase_nameSED.drop_user_if_exists() ;
DROP PROCEDURE IF EXISTS SEDdatabase_nameSED.drop_users_if_exists ;


