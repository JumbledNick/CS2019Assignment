-- =============================================================================
--  CS2019 Assessment 2 : Arts Museum Database
--  Script 1 of 4 : database and tables            Target : MySQL 8.0.16+ (InnoDB)
--  Conventions    : tables PascalCase, columns camelCase,
--                   constraint prefixes ck_ (CHECK), fk_ (FOREIGN KEY), uq_ (UNIQUE)
-- =============================================================================
DROP DATABASE IF EXISTS ArtsMuseumDB;
CREATE DATABASE ArtsMuseumDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ArtsMuseumDB;

-- -----------------------------------------------------------------------------
-- A. Controlled vocabularies. The brief lists open-ended values ("etc.") that
--    are shared by several entities, so each gets a lookup table: one spelling
--    per value and no repeated text.
-- -----------------------------------------------------------------------------
CREATE TABLE Origin (
  originID   SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  originName VARCHAR(60)       NOT NULL,            -- country or culture, e.g. Italian
  PRIMARY KEY (originID),
  UNIQUE KEY uq_origin_name (originName)
) ENGINE=InnoDB;

CREATE TABLE Epoch (
  epochID   SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  epochName VARCHAR(60)       NOT NULL,             -- e.g. Renaissance, Modern, Ancient
  PRIMARY KEY (epochID),
  UNIQUE KEY uq_epoch_name (epochName)
) ENGINE=InnoDB;

CREATE TABLE Style (
  styleID   SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  styleName VARCHAR(60)       NOT NULL,             -- e.g. Classic, Modern, Abstract
  PRIMARY KEY (styleID),
  UNIQUE KEY uq_style_name (styleName)
) ENGINE=InnoDB;

CREATE TABLE Material (
  materialID   SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  materialName VARCHAR(60)       NOT NULL,          -- e.g. Canvas, Paper, Wood, Marble
  PRIMARY KEY (materialID),
  UNIQUE KEY uq_material_name (materialName)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- B. Arts Friends Circle members and artists
-- -----------------------------------------------------------------------------
CREATE TABLE Museum (
  museumID    INT UNSIGNED NOT NULL AUTO_INCREMENT,  -- surrogate key
  museumName  VARCHAR(100) NOT NULL,                 -- unique in the brief
  description TEXT         NULL,
  address     VARCHAR(200) NOT NULL,                 -- treated as one atomic value
  phone       VARCHAR(25)  NOT NULL,
  contactName VARCHAR(100) NOT NULL,                 -- current contact person
  PRIMARY KEY (museumID),
  UNIQUE KEY uq_museum_name (museumName)
) ENGINE=InnoDB;

CREATE TABLE Artist (
  artistID    INT UNSIGNED NOT NULL AUTO_INCREMENT,  -- surrogate key
  artistName  VARCHAR(100) NOT NULL,
  dateBorn    DATE         NOT NULL,
  dateDied    DATE         NULL,                     -- NULL = still living
  -- UNIQUE ignores NULLs, so living artists need a stand-in value to keep
  -- (name, dateBorn, dateDied) unique exactly as the brief demands.
  dateDiedKey DATE GENERATED ALWAYS AS (IFNULL(dateDied, '9999-12-31')) STORED,
  originID    SMALLINT UNSIGNED NULL,
  epochID     SMALLINT UNSIGNED NULL,
  mainStyleID SMALLINT UNSIGNED NULL,
  description TEXT         NULL,
  PRIMARY KEY (artistID),
  UNIQUE KEY uq_artist_identity (artistName, dateBorn, dateDiedKey),
  CONSTRAINT ck_artist_dates CHECK (dateDied IS NULL OR dateDied >= dateBorn),
  CONSTRAINT fk_artist_origin FOREIGN KEY (originID)
    REFERENCES Origin (originID) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_artist_epoch FOREIGN KEY (epochID)
    REFERENCES Epoch (epochID) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_artist_style FOREIGN KEY (mainStyleID)
    REFERENCES Style (styleID) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- C. Exhibitions (generalisation: Exhibition -> Regular | Featured) and galleries
-- -----------------------------------------------------------------------------
CREATE TABLE Exhibition (
  exhibitionID   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  exhibitionName VARCHAR(120) NOT NULL,
  description    TEXT         NULL,
  exhibitionKind ENUM('REGULAR','FEATURED') NOT NULL,   -- discriminator
  PRIMARY KEY (exhibitionID),
  UNIQUE KEY uq_exhibition_name (exhibitionName)
) ENGINE=InnoDB;

CREATE TABLE RegularExhibition (
  exhibitionID INT UNSIGNED NOT NULL,
  PRIMARY KEY (exhibitionID),
  CONSTRAINT fk_regular_exhibition FOREIGN KEY (exhibitionID)
    REFERENCES Exhibition (exhibitionID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE FeaturedExhibition (
  exhibitionID INT UNSIGNED NOT NULL,
  startDate    DATE NOT NULL,
  endDate      DATE NOT NULL,
  PRIMARY KEY (exhibitionID),
  CONSTRAINT ck_featured_dates CHECK (endDate >= startDate),
  CONSTRAINT fk_featured_exhibition FOREIGN KEY (exhibitionID)
    REFERENCES Exhibition (exhibitionID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Gallery (                                -- part of one regular exhibition
  galleryID           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  galleryName         VARCHAR(80)  NOT NULL,
  floorLevel          TINYINT      NOT NULL DEFAULT 0,  -- 0 = ground floor
  regularExhibitionID INT UNSIGNED NOT NULL,
  PRIMARY KEY (galleryID),
  UNIQUE KEY uq_gallery_name (galleryName),
  CONSTRAINT fk_gallery_regular FOREIGN KEY (regularExhibitionID)
    REFERENCES RegularExhibition (exhibitionID) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- D. Art objects: superclass plus one table per subclass (shared primary key)
--    Two independent specialisations: category (4 subclasses) and ownership (2).
-- -----------------------------------------------------------------------------
CREATE TABLE ArtObject (
  objectID    CHAR(6)      NOT NULL,                  -- AOXXXX
  title       VARCHAR(150) NOT NULL,
  description TEXT         NOT NULL,
  yearCreated SMALLINT     NULL,                      -- negative = BCE, NULL = unknown
  category    ENUM('PAINTING','SCULPTURE','STATUE','OTHER') NOT NULL,   -- discriminator 1
  ownership   ENUM('PERMANENT','BORROWED') NOT NULL,                    -- discriminator 2
  status      ENUM('ON_DISPLAY','IN_STORE','UNDER_RESTORATION','ON_LOAN','RETURNED')
              NOT NULL DEFAULT 'IN_STORE',
  artistID    INT UNSIGNED NULL,                      -- NULL = unknown / anonymous artist
  originID    SMALLINT UNSIGNED NOT NULL,
  epochID     SMALLINT UNSIGNED NOT NULL,
  styleID     SMALLINT UNSIGNED NOT NULL,
  galleryID   INT UNSIGNED NULL,                      -- set only while ON_DISPLAY
  PRIMARY KEY (objectID),
  CONSTRAINT ck_ao_id CHECK (objectID REGEXP '^AO[0-9]{4}$'),
  CONSTRAINT ck_ao_year CHECK (yearCreated IS NULL OR yearCreated BETWEEN -5000 AND 2100),
  CONSTRAINT ck_ao_ownership_status CHECK (
        (ownership = 'PERMANENT' AND status <> 'RETURNED')
     OR (ownership = 'BORROWED'  AND status <> 'ON_LOAN')),
  CONSTRAINT fk_ao_artist FOREIGN KEY (artistID)
    REFERENCES Artist (artistID) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ao_origin FOREIGN KEY (originID)
    REFERENCES Origin (originID) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ao_epoch FOREIGN KEY (epochID)
    REFERENCES Epoch (epochID) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ao_style FOREIGN KEY (styleID)
    REFERENCES Style (styleID) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ao_gallery FOREIGN KEY (galleryID)
    REFERENCES Gallery (galleryID) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Painting (
  objectID          CHAR(6)     NOT NULL,
  paintingMedium    VARCHAR(40) NOT NULL,             -- oil, watercolour, acrylic ...
  surfaceMaterialID SMALLINT UNSIGNED NULL,           -- "usually" painted on paper, canvas, wood
  PRIMARY KEY (objectID),
  CONSTRAINT fk_painting_object FOREIGN KEY (objectID)
    REFERENCES ArtObject (objectID) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_painting_surface FOREIGN KEY (surfaceMaterialID)
    REFERENCES Material (materialID) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Sculpture (
  objectID   CHAR(6)       NOT NULL,
  materialID SMALLINT UNSIGNED NOT NULL,
  heightCm   DECIMAL(7,2)  NOT NULL,
  weightKg   DECIMAL(9,2)  NOT NULL,
  PRIMARY KEY (objectID),
  CONSTRAINT ck_sculpture_size CHECK (heightCm > 0 AND weightKg > 0),
  CONSTRAINT fk_sculpture_object FOREIGN KEY (objectID)
    REFERENCES ArtObject (objectID) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_sculpture_material FOREIGN KEY (materialID)
    REFERENCES Material (materialID) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Statue (
  objectID   CHAR(6)       NOT NULL,
  materialID SMALLINT UNSIGNED NOT NULL,
  heightCm   DECIMAL(7,2)  NOT NULL,
  weightKg   DECIMAL(9,2)  NOT NULL,
  PRIMARY KEY (objectID),
  CONSTRAINT ck_statue_size CHECK (heightCm > 0 AND weightKg > 0),
  CONSTRAINT fk_statue_object FOREIGN KEY (objectID)
    REFERENCES ArtObject (objectID) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_statue_material FOREIGN KEY (materialID)
    REFERENCES Material (materialID) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE OtherObject (
  objectID  CHAR(6)     NOT NULL,
  otherType VARCHAR(40) NOT NULL,                     -- print, photograph, drawing ...
  PRIMARY KEY (objectID),
  CONSTRAINT fk_other_object FOREIGN KEY (objectID)
    REFERENCES ArtObject (objectID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE PermanentObject (
  objectID        CHAR(6)       NOT NULL,
  acquisitionDate DATE          NOT NULL,
  acquisitionCost DECIMAL(12,2) NOT NULL,             -- pounds sterling; 0.00 for gifts
  PRIMARY KEY (objectID),
  CONSTRAINT ck_permanent_cost CHECK (acquisitionCost >= 0),
  CONSTRAINT fk_permanent_object FOREIGN KEY (objectID)
    REFERENCES ArtObject (objectID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE BorrowedObject (
  objectID CHAR(6) NOT NULL,
  PRIMARY KEY (objectID),
  CONSTRAINT fk_borrowed_object FOREIGN KEY (objectID)
    REFERENCES ArtObject (objectID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Borrowing (                              -- loans INTO this museum
  objectID     CHAR(6) NOT NULL,
  dateBorrowed DATE    NOT NULL,
  museumID     INT UNSIGNED NOT NULL,                 -- the lender
  dateDue      DATE    NOT NULL,                      -- date to be returned
  dateReturned DATE    NULL,                          -- NULL = still held
  PRIMARY KEY (objectID, dateBorrowed),
  CONSTRAINT ck_borrowing_due CHECK (dateDue >= dateBorrowed),
  CONSTRAINT ck_borrowing_returned CHECK (dateReturned IS NULL OR dateReturned >= dateBorrowed),
  CONSTRAINT fk_borrowing_object FOREIGN KEY (objectID)
    REFERENCES BorrowedObject (objectID) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_borrowing_museum FOREIGN KEY (museumID)
    REFERENCES Museum (museumID) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Lending (                                -- loans OUT of this museum
  objectID     CHAR(6) NOT NULL,
  dateLent     DATE    NOT NULL,
  museumID     INT UNSIGNED NOT NULL,                 -- the borrower
  dateDue      DATE    NOT NULL,
  dateReturned DATE    NULL,                          -- NULL = still away
  PRIMARY KEY (objectID, dateLent),
  CONSTRAINT ck_lending_due CHECK (dateDue >= dateLent),
  CONSTRAINT ck_lending_returned CHECK (dateReturned IS NULL OR dateReturned >= dateLent),
  CONSTRAINT fk_lending_object FOREIGN KEY (objectID)
    REFERENCES PermanentObject (objectID) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_lending_museum FOREIGN KEY (museumID)
    REFERENCES Museum (museumID) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- E. Featured exhibitions: features, selected objects, replica sales
-- -----------------------------------------------------------------------------
CREATE TABLE ExhibitionFeature (                      -- multi-valued composite attribute
  exhibitionID INT UNSIGNED NOT NULL,
  featureType  ENUM('ARTIST','CATEGORY','STYLE','EPOCH','ORIGIN') NOT NULL,
  featureValue VARCHAR(100) NOT NULL,                 -- e.g. STYLE / Impressionist
  PRIMARY KEY (exhibitionID, featureType, featureValue),
  CONSTRAINT fk_exfeature_exhibition FOREIGN KEY (exhibitionID)
    REFERENCES FeaturedExhibition (exhibitionID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE ExhibitionObject (                       -- objects used in a featured exhibition
  exhibitionID INT UNSIGNED NOT NULL,
  objectID     CHAR(6)      NOT NULL,
  PRIMARY KEY (exhibitionID, objectID),
  CONSTRAINT fk_exobject_exhibition FOREIGN KEY (exhibitionID)
    REFERENCES FeaturedExhibition (exhibitionID) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_exobject_object FOREIGN KEY (objectID)
    REFERENCES ArtObject (objectID) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE ReplicaSale (                            -- replicas sold during an exhibition
  exhibitionID INT UNSIGNED NOT NULL,
  objectID     CHAR(6)      NOT NULL,
  unitPrice    DECIMAL(8,2) NOT NULL,
  quantitySold INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (exhibitionID, objectID),
  CONSTRAINT ck_replica_price CHECK (unitPrice >= 0),
  -- a replica can only be sold for an object that is part of that exhibition
  CONSTRAINT fk_replica_exobject FOREIGN KEY (exhibitionID, objectID)
    REFERENCES ExhibitionObject (exhibitionID, objectID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- F. Loyal visitors, preferences and invitations
-- -----------------------------------------------------------------------------
CREATE TABLE LoyalVisitor (
  loyaltyNo CHAR(6)      NOT NULL,                    -- LMYYYY
  firstName VARCHAR(50)  NOT NULL,
  lastName  VARCHAR(50)  NOT NULL,
  address   VARCHAR(200) NOT NULL,
  email     VARCHAR(120) NULL,
  phone     VARCHAR(25)  NULL,
  joinDate  DATE         NOT NULL,
  PRIMARY KEY (loyaltyNo),
  UNIQUE KEY uq_visitor_email (email),
  CONSTRAINT ck_visitor_no CHECK (loyaltyNo REGEXP '^LM[0-9]{4}$')
) ENGINE=InnoDB;

CREATE TABLE VisitorPreference (                      -- multi-valued composite attribute
  loyaltyNo    CHAR(6)      NOT NULL,
  featureType  ENUM('ARTIST','CATEGORY','STYLE','EPOCH','ORIGIN') NOT NULL,
  featureValue VARCHAR(100) NOT NULL,
  PRIMARY KEY (loyaltyNo, featureType, featureValue),
  CONSTRAINT fk_pref_visitor FOREIGN KEY (loyaltyNo)
    REFERENCES LoyalVisitor (loyaltyNo) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Invitation (
  loyaltyNo    CHAR(6)      NOT NULL,
  exhibitionID INT UNSIGNED NOT NULL,
  sentDate     DATE         NOT NULL,
  channel      ENUM('EMAIL','POST','SMS') NOT NULL,
  response     ENUM('PENDING','ACCEPTED','DECLINED') NOT NULL DEFAULT 'PENDING',
  PRIMARY KEY (loyaltyNo, exhibitionID),
  CONSTRAINT fk_invitation_visitor FOREIGN KEY (loyaltyNo)
    REFERENCES LoyalVisitor (loyaltyNo) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_invitation_exhibition FOREIGN KEY (exhibitionID)
    REFERENCES FeaturedExhibition (exhibitionID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- G. Staff (generalisation: Staff -> Curator | Supervisor | other) and duties
-- -----------------------------------------------------------------------------
CREATE TABLE Staff (
  staffID   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  firstName VARCHAR(50)  NOT NULL,
  lastName  VARCHAR(50)  NOT NULL,
  jobTitle  VARCHAR(60)  NOT NULL,
  staffType ENUM('CURATOR','SUPERVISOR','OTHER') NOT NULL,   -- discriminator
  phone     VARCHAR(25)  NULL,
  email     VARCHAR(120) NOT NULL,
  hireDate  DATE         NOT NULL,
  PRIMARY KEY (staffID),
  UNIQUE KEY uq_staff_email (email)
) ENGINE=InnoDB;

CREATE TABLE Curator (
  staffID        INT UNSIGNED NOT NULL,
  specialisation ENUM('PAINTING','SCULPTURE','STATUE','OTHER') NOT NULL,
  maxObjects     TINYINT UNSIGNED NOT NULL DEFAULT 20,       -- "certain number (say 20)"
  PRIMARY KEY (staffID),
  CONSTRAINT ck_curator_max CHECK (maxObjects BETWEEN 1 AND 100),
  CONSTRAINT fk_curator_staff FOREIGN KEY (staffID)
    REFERENCES Staff (staffID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Supervisor (
  staffID INT UNSIGNED NOT NULL,
  PRIMARY KEY (staffID),
  CONSTRAINT fk_supervisor_staff FOREIGN KEY (staffID)
    REFERENCES Staff (staffID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Maintains (                              -- curator <-> art object (M:N)
  staffID      INT UNSIGNED NOT NULL,
  objectID     CHAR(6)      NOT NULL,
  assignedDate DATE         NOT NULL,
  PRIMARY KEY (staffID, objectID),
  CONSTRAINT fk_maintains_curator FOREIGN KEY (staffID)
    REFERENCES Curator (staffID) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_maintains_object FOREIGN KEY (objectID)
    REFERENCES ArtObject (objectID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE SupervisesGallery (                      -- supervisor <-> gallery over time
  staffID   INT UNSIGNED NOT NULL,
  galleryID INT UNSIGNED NOT NULL,
  fromDate  DATE         NOT NULL,
  toDate    DATE         NULL,                        -- NULL = current allocation
  PRIMARY KEY (staffID, galleryID, fromDate),
  CONSTRAINT ck_supgallery_dates CHECK (toDate IS NULL OR toDate >= fromDate),
  CONSTRAINT fk_supgallery_supervisor FOREIGN KEY (staffID)
    REFERENCES Supervisor (staffID) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_supgallery_gallery FOREIGN KEY (galleryID)
    REFERENCES Gallery (galleryID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE SupervisesFeatured (                     -- supervisor <-> featured exhibition
  staffID      INT UNSIGNED NOT NULL,
  exhibitionID INT UNSIGNED NOT NULL,
  allocatedOn  DATE         NOT NULL,
  PRIMARY KEY (staffID, exhibitionID),
  CONSTRAINT fk_supfeatured_supervisor FOREIGN KEY (staffID)
    REFERENCES Supervisor (staffID) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_supfeatured_exhibition FOREIGN KEY (exhibitionID)
    REFERENCES FeaturedExhibition (exhibitionID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
