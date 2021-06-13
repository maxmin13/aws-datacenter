/*
	this file creates the required Database users for MYDB
	these are:
	
	adminrw
		full access with grant

	webphprw
		can read, update, insert required tables for website
	
	javamail
		can read, update required tables for sending mail
	

	useful SQL commands	
	GRANT ALL PRIVILEGES  ON MYDB.* TO 'adminrw'@'%' WITH GRANT OPTION;
	GRANT SELECT, INSERT ON MYDB.* TO 'someuser'@'somehost';
	GRANT SELECT (col1), INSERT (col1,col2) ON MYDB.mytable TO 'someuser'@'somehost';
	
*/

/* Do admin first so that if there are any errors at least we can connect to Admin server */
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

CREATE USER 'SEDDBUSR_adminrwSED'@'%' IDENTIFIED BY 'SEDDBPASS_adminrwSED';
GRANT ALL PRIVILEGES  ON SEDdatabase_nameSED.* TO 'SEDDBUSR_adminrwSED'@'%' WITH GRANT OPTION;
GRANT SELECT ON mysql.slow_log TO 'SEDDBUSR_adminrwSED'@'%';


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

CREATE USER 'SEDDBUSR_webphprwSED'@'%' IDENTIFIED BY 'SEDDBPASS_webphprwSED';
GRANT SELECT, INSERT, UPDATE 		 ON SEDdatabase_nameSED.users TO 'SEDDBUSR_webphprwSED'@'%';
GRANT SELECT, INSERT			 		 ON SEDdatabase_nameSED.sendemails TO 'SEDDBUSR_webphprwSED'@'%';
GRANT SELECT, INSERT			 		 ON SEDdatabase_nameSED.snsnotifications TO 'SEDDBUSR_webphprwSED'@'%';


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

CREATE USER 'SEDDBUSR_javamailSED'@'%' IDENTIFIED BY 'SEDDBPASS_javamailSED';
GRANT SELECT,			UPDATE 		 ON SEDdatabase_nameSED.sendemails TO 'SEDDBUSR_javamailSED'@'%';
