-- =============================================================================
--  CS2019 Assessment 2 : Arts Museum Database
--  Script 3 of 4 : views and triggers
--  Triggers are installed after the sample data has been loaded.
--  (The mysql client and MySQL Workbench understand the DELIMITER command.)
-- =============================================================================
USE ArtsMuseumDB;

-- -----------------------------------------------------------------------------
-- Views
-- -----------------------------------------------------------------------------
-- What visitors may see next to an object in ANY exhibition: title, artist, year,
-- description, origin and epoch. Acquisition cost, acquisition date and loan
-- details are deliberately left out ("this information is not displayed").
CREATE OR REPLACE VIEW vw_ObjectDisplayInfo AS
SELECT ao.objectID, ao.title, a.artistName, ao.yearCreated, ao.description,
       o.originName AS countryOrCulture, e.epochName, s.styleName,
       ao.category, g.galleryName
FROM ArtObject ao
JOIN Origin o ON o.originID = ao.originID
JOIN Epoch  e ON e.epochID  = ao.epochID
JOIN Style  s ON s.styleID  = ao.styleID
LEFT JOIN Artist  a ON a.artistID  = ao.artistID
LEFT JOIN Gallery g ON g.galleryID = ao.galleryID;

-- Catalogue of every featured exhibition: only the public display information.
CREATE OR REPLACE VIEW vw_FeaturedExhibitionCatalogue AS
SELECT e.exhibitionName, fe.startDate, fe.endDate,
       d.objectID, d.title, d.artistName, d.yearCreated, d.description,
       d.countryOrCulture, d.epochName, d.category
FROM FeaturedExhibition fe
JOIN Exhibition e ON e.exhibitionID = fe.exhibitionID
JOIN ExhibitionObject eo ON eo.exhibitionID = fe.exhibitionID
JOIN vw_ObjectDisplayInfo d ON d.objectID = eo.objectID;

-- Objects that are borrowed and not yet returned (internal use only).
CREATE OR REPLACE VIEW vw_BorrowedObjectsHeld AS
SELECT ao.objectID, ao.title, m.museumName AS lender,
       b.dateBorrowed, b.dateDue
FROM Borrowing b
JOIN ArtObject ao ON ao.objectID = b.objectID
JOIN Museum m ON m.museumID = b.museumID
WHERE b.dateReturned IS NULL;

-- -----------------------------------------------------------------------------
-- Triggers: business rules that a CHECK or FOREIGN KEY cannot express because
-- they look at another table.
-- -----------------------------------------------------------------------------
DELIMITER $$

-- 1. A subclass row may only be attached to a superclass row of the right kind
--    (this keeps each generalisation disjoint).
CREATE TRIGGER trg_painting_bi BEFORE INSERT ON Painting FOR EACH ROW
BEGIN
  IF (SELECT category FROM ArtObject WHERE objectID = NEW.objectID) <> 'PAINTING' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Painting needs an ArtObject with category PAINTING';
  END IF;
END$$

CREATE TRIGGER trg_sculpture_bi BEFORE INSERT ON Sculpture FOR EACH ROW
BEGIN
  IF (SELECT category FROM ArtObject WHERE objectID = NEW.objectID) <> 'SCULPTURE' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sculpture needs an ArtObject with category SCULPTURE';
  END IF;
END$$

CREATE TRIGGER trg_statue_bi BEFORE INSERT ON Statue FOR EACH ROW
BEGIN
  IF (SELECT category FROM ArtObject WHERE objectID = NEW.objectID) <> 'STATUE' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Statue needs an ArtObject with category STATUE';
  END IF;
END$$

CREATE TRIGGER trg_other_bi BEFORE INSERT ON OtherObject FOR EACH ROW
BEGIN
  IF (SELECT category FROM ArtObject WHERE objectID = NEW.objectID) <> 'OTHER' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OtherObject needs an ArtObject with category OTHER';
  END IF;
END$$

CREATE TRIGGER trg_permanent_bi BEFORE INSERT ON PermanentObject FOR EACH ROW
BEGIN
  IF (SELECT ownership FROM ArtObject WHERE objectID = NEW.objectID) <> 'PERMANENT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PermanentObject needs an ArtObject with ownership PERMANENT';
  END IF;
END$$

CREATE TRIGGER trg_borrowed_bi BEFORE INSERT ON BorrowedObject FOR EACH ROW
BEGIN
  IF (SELECT ownership FROM ArtObject WHERE objectID = NEW.objectID) <> 'BORROWED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'BorrowedObject needs an ArtObject with ownership BORROWED';
  END IF;
END$$

CREATE TRIGGER trg_regular_bi BEFORE INSERT ON RegularExhibition FOR EACH ROW
BEGIN
  IF (SELECT exhibitionKind FROM Exhibition WHERE exhibitionID = NEW.exhibitionID) <> 'REGULAR' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RegularExhibition needs an Exhibition of kind REGULAR';
  END IF;
END$$

CREATE TRIGGER trg_featured_bi BEFORE INSERT ON FeaturedExhibition FOR EACH ROW
BEGIN
  IF (SELECT exhibitionKind FROM Exhibition WHERE exhibitionID = NEW.exhibitionID) <> 'FEATURED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FeaturedExhibition needs an Exhibition of kind FEATURED';
  END IF;
END$$

CREATE TRIGGER trg_curator_bi BEFORE INSERT ON Curator FOR EACH ROW
BEGIN
  IF (SELECT staffType FROM Staff WHERE staffID = NEW.staffID) <> 'CURATOR' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Curator needs a Staff member of type CURATOR';
  END IF;
END$$

CREATE TRIGGER trg_supervisor_bi BEFORE INSERT ON Supervisor FOR EACH ROW
BEGIN
  IF (SELECT staffType FROM Staff WHERE staffID = NEW.staffID) <> 'SUPERVISOR' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Supervisor needs a Staff member of type SUPERVISOR';
  END IF;
END$$

-- 2. An object is ON_DISPLAY exactly when it hangs in a gallery; category and
--    ownership are fixed once an object has been registered.
CREATE TRIGGER trg_artobject_bi BEFORE INSERT ON ArtObject FOR EACH ROW
BEGIN
  IF (NEW.status = 'ON_DISPLAY') <> (NEW.galleryID IS NOT NULL) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'ON_DISPLAY objects need a gallery; any other status must have no gallery';
  END IF;
END$$

CREATE TRIGGER trg_artobject_bu BEFORE UPDATE ON ArtObject FOR EACH ROW
BEGIN
  IF NEW.category <> OLD.category OR NEW.ownership <> OLD.ownership THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'category and ownership cannot be changed after registration';
  END IF;
  IF (NEW.status = 'ON_DISPLAY') <> (NEW.galleryID IS NOT NULL) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'ON_DISPLAY objects need a gallery; any other status must have no gallery';
  END IF;
END$$

-- 3. A curator maintains only objects of his or her specialisation and never
--    more than maxObjects objects.
CREATE TRIGGER trg_maintains_bi BEFORE INSERT ON Maintains FOR EACH ROW
BEGIN
  DECLARE v_spec VARCHAR(10);
  DECLARE v_max  INT;
  DECLARE v_cat  VARCHAR(10);
  DECLARE v_cnt  INT;
  SELECT specialisation, maxObjects INTO v_spec, v_max
    FROM Curator WHERE staffID = NEW.staffID;
  SELECT category INTO v_cat FROM ArtObject WHERE objectID = NEW.objectID;
  IF v_spec <> v_cat THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Curator specialisation does not match the art object category';
  END IF;
  SELECT COUNT(*) INTO v_cnt FROM Maintains WHERE staffID = NEW.staffID;
  IF v_cnt >= v_max THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Curator already maintains the maximum number of art objects';
  END IF;
END$$

CREATE TRIGGER trg_maintains_bu BEFORE UPDATE ON Maintains FOR EACH ROW
BEGIN
  DECLARE v_spec VARCHAR(10);
  DECLARE v_max  INT;
  DECLARE v_cat  VARCHAR(10);
  DECLARE v_cnt  INT;
  SELECT specialisation, maxObjects INTO v_spec, v_max
    FROM Curator WHERE staffID = NEW.staffID;
  SELECT category INTO v_cat FROM ArtObject WHERE objectID = NEW.objectID;
  IF v_spec <> v_cat THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Curator specialisation does not match the art object category';
  END IF;
  SELECT COUNT(*) INTO v_cnt FROM Maintains
   WHERE staffID = NEW.staffID
     AND NOT (staffID = OLD.staffID AND objectID = OLD.objectID);
  IF v_cnt >= v_max THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Curator already maintains the maximum number of art objects';
  END IF;
END$$

DELIMITER ;
