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

-- =============================================================================
--  CS2019 Assessment 2 : Arts Museum Database
--  Script 2 of 4 : sample data (every table has more than five rows)
--  Rows are inserted parents-first so that every foreign key is satisfied.
-- =============================================================================
USE ArtsMuseumDB;
SET NAMES utf8mb4;

-- Origin (8 rows)
INSERT INTO Origin (originID, originName) VALUES
  (1, 'Italian'),
  (2, 'Greek'),
  (3, 'Indian'),
  (4, 'French'),
  (5, 'Dutch'),
  (6, 'British'),
  (7, 'Spanish'),
  (8, 'Japanese');

-- Epoch (7 rows)
INSERT INTO Epoch (epochID, epochName) VALUES
  (1, 'Ancient'),
  (2, 'Medieval'),
  (3, 'Renaissance'),
  (4, 'Baroque'),
  (5, 'Edo Period'),
  (6, 'Modern'),
  (7, 'Contemporary');

-- Style (8 rows)
INSERT INTO Style (styleID, styleName) VALUES
  (1, 'Classic'),
  (2, 'Realist'),
  (3, 'Baroque'),
  (4, 'Impressionist'),
  (5, 'Cubist'),
  (6, 'Abstract'),
  (7, 'Modernist'),
  (8, 'Ukiyo-e');

-- Material (8 rows)
INSERT INTO Material (materialID, materialName) VALUES
  (1, 'Canvas'),
  (2, 'Paper'),
  (3, 'Wood'),
  (4, 'Marble'),
  (5, 'Bronze'),
  (6, 'Limestone'),
  (7, 'Terracotta'),
  (8, 'Plaster');

-- Museum (7 rows)
INSERT INTO Museum (museumID, museumName, description, address, phone, contactName) VALUES
  (1, 'Riverside Museum of Fine Art',
    'Tay waterfront museum with strong Dutch and French collections.',
    '21 Quayside Walk, Dundee DD1 4QA', '01632 960211', 'Fiona McKenzie'),
  (2, 'Highland Heritage Gallery', 'Regional gallery of Highland and medieval art.',
    '5 Castle Wynd, Inverness IV2 3EE', '01632 960322', 'Callum Fraser'),
  (3, 'Thistle Modern Art Centre', 'Centre for modern and contemporary art.',
    '88 Sauchiehall Lane, Glasgow G2 3AB', '0141 496 0433', 'Priya Nair'),
  (4, 'Tay Valley Art Museum', 'Museum of seventeenth to nineteenth century painting.',
    '3 Kinnoull Terrace, Perth PH2 7BT', '01632 960544', 'Douglas Reid'),
  (5, 'Forth Maritime Arts Museum', 'Art of harbours, ships and the sea.',
    '14 Shore Road, Edinburgh EH6 6QW', '0131 496 0655', 'Eilidh Stewart'),
  (6, 'Castlegate Sculpture Museum', 'Specialist museum of sculpture and statuary.',
    '9 Upper Bridge Street, Stirling FK8 1AA', '01632 960766', 'Martin Gallagher'),
  (7, 'Solway Print and Photography Museum', 'Collection of prints, drawings and photographs.',
    '27 High Street, Dumfries DG1 2JD', '01632 960877', 'Hannah Brodie');

-- Artist (10 rows)
INSERT INTO Artist (artistID, artistName, dateBorn, dateDied, originID, epochID, mainStyleID, description) VALUES
  (1, 'Giulia Marchetti', '1601-03-12', '1672-09-04', 1, 4, 3,
    'Painter of religious scenes in the Roman Baroque tradition.'),
  (2, 'Pieter van der Linden', '1620-05-21', '1689-11-30', 5, 4, 2,
    'Dutch painter of harbours and merchant portraits.'),
  (3, 'Élodie Vasseur', '1845-07-09', '1919-02-17', 4, 6, 4,
    'Painter of domestic interiors and everyday life.'),
  (4, 'Rajesh Varma', '1932-11-02', '2004-06-19', 3, 6, 6,
    'Pioneer of geometric abstraction in post-independence India.'),
  (5, 'Hiroshi Tanaka', '1958-04-23', NULL, 8, 7, 7,
    'Living sculptor working in bronze and stone.'),
  (6, 'Margaret Ellison', '1903-08-14', '1988-01-30', 6, 6, 7,
    'British sculptor known for organic wood and bronze figures.'),
  (7, 'Carlos Ibarra Soler', '1889-10-02', '1971-12-11', 7, 6, 5,
    'Spanish sculptor and draughtsman of the Cubist circle.'),
  (8, 'Tomasso Berardi', '1470-02-11', '1541-08-23', 1, 3, 1,
    'Florentine sculptor of marble and bronze figures.'),
  (9, 'Shunpei Katsura', '1771-04-05', '1844-09-12', 8, 5, 8,
    'Japanese woodblock printmaker of the Edo period.'),
  (10, 'Isla MacRae', '1901-06-03', '1984-02-21', 6, 6, 2,
    'Scottish documentary photographer of harbours and street life.');

-- Exhibition (12 rows)
INSERT INTO Exhibition (exhibitionID, exhibitionName, description, exhibitionKind) VALUES
  (1, 'European Masters',
    'Permanent display of European painting from the sixteenth to nineteenth centuries.',
    'REGULAR'),
  (2, 'Ancient Worlds', 'Greek, Roman and early Mediterranean art.', 'REGULAR'),
  (3, 'Sculpture Court', 'Permanent display of sculpture and statuary.', 'REGULAR'),
  (4, 'Modern and Contemporary', 'Twentieth and twenty-first century art.', 'REGULAR'),
  (5, 'Asian Art', 'Art of India, Japan and East Asia.', 'REGULAR'),
  (6, 'Prints and Photography', 'Works on paper and photographic prints.', 'REGULAR'),
  (7, 'Light and Water: The Impressionist Vision',
    'Impressionist paintings of light, water and everyday life.', 'FEATURED'),
  (8, 'Gods and Heroes in Marble',
    'Marble statues of gods and heroes from Greece and Renaissance Italy.', 'FEATURED'),
  (9, 'The Dutch Golden Age', 'Dutch Baroque harbours, portraits and still life.', 'FEATURED'),
  (10, 'Modern Abstractions', 'Abstract art of the twentieth and twenty-first centuries.',
    'FEATURED'),
  (11, 'Prints of the Floating World', 'Japanese woodblock prints of the Edo period.', 'FEATURED'),
  (12, 'Marchetti: A Baroque Life', 'Paintings and drawings by Giulia Marchetti.', 'FEATURED');

-- RegularExhibition (6 rows)
INSERT INTO RegularExhibition (exhibitionID) VALUES
  (1),
  (2),
  (3),
  (4),
  (5),
  (6);

-- FeaturedExhibition (6 rows)
INSERT INTO FeaturedExhibition (exhibitionID, startDate, endDate) VALUES
  (7, '2026-03-01', '2026-06-30'),
  (8, '2026-05-15', '2026-09-30'),
  (9, '2026-09-01', '2026-12-31'),
  (10, '2026-10-10', '2027-01-31'),
  (11, '2027-02-15', '2027-05-30'),
  (12, '2027-03-01', '2027-07-31');

-- Gallery (8 rows)
INSERT INTO Gallery (galleryID, galleryName, floorLevel, regularExhibitionID) VALUES
  (1, 'Baroque Hall', 1, 1),
  (2, 'Impressionist Room', 1, 1),
  (3, 'Hellenic Gallery', 0, 2),
  (4, 'Marble Court', 0, 3),
  (5, 'Bronze Gallery', 0, 3),
  (6, 'Abstract Gallery', 2, 4),
  (7, 'Japanese Print Room', 2, 5),
  (8, 'Works on Paper Room', 1, 6);

-- ArtObject (24 rows)
INSERT INTO ArtObject (objectID, title, description, yearCreated, category, ownership, status, artistID, originID, epochID, styleID, galleryID) VALUES
  ('AO0001', 'Harbour at Dawn', 'Fishing boats leave a misty Dutch harbour at first light.',
    1655, 'PAINTING', 'PERMANENT', 'ON_DISPLAY', 2, 5, 4, 2, 1),
  ('AO0002', 'The Seamstress',
    'A woman sews by a sunlit window, painted in loose, feathery brushwork.', 1889, 'PAINTING',
    'PERMANENT', 'ON_DISPLAY', 3, 4, 6, 4, 2),
  ('AO0003', 'Saint Cecilia at the Organ', 'The patron saint of music, lit by a single candle.',
    1638, 'PAINTING', 'PERMANENT', 'ON_DISPLAY', 1, 1, 4, 3, 1),
  ('AO0004', 'Monsoon Geometry No. 4',
    'Interlocking blue and ochre forms evoking monsoon skies.', 1968, 'PAINTING', 'PERMANENT',
    'ON_DISPLAY', 4, 3, 6, 6, 6),
  ('AO0005', 'Portrait of a Merchant''s Wife',
    'Half-length portrait of a Dutch merchant''s wife in black silk.', 1662, 'PAINTING',
    'BORROWED', 'ON_DISPLAY', 2, 5, 4, 2, 1),
  ('AO0006', 'Winter Orchard', 'Delicate watercolour of an orchard under frost.', 1894,
    'PAINTING', 'BORROWED', 'IN_STORE', 3, 4, 6, 4, NULL),
  ('AO0007', 'Reclining Figure in Elm', 'Carved elm figure with smooth, flowing curves.', 1952,
    'SCULPTURE', 'PERMANENT', 'ON_DISPLAY', 6, 6, 6, 7, 4),
  ('AO0008', 'Mother and Child (Study)', 'Bronze study for a larger public commission.', 1949,
    'SCULPTURE', 'PERMANENT', 'UNDER_RESTORATION', 6, 6, 6, 7, NULL),
  ('AO0009', 'Wave Form', 'Abstract limestone sculpture suggesting a breaking wave.', 2011,
    'SCULPTURE', 'PERMANENT', 'ON_DISPLAY', 5, 8, 7, 6, 5),
  ('AO0010', 'Horse Head Fragment',
    'Marble fragment from a Greek horse sculpture; maker unknown.', -450, 'SCULPTURE',
    'PERMANENT', 'IN_STORE', NULL, 2, 1, 1, NULL),
  ('AO0011', 'Carved Temple Guardian', 'Guardian figure from a medieval Indian temple doorway.',
    1150, 'SCULPTURE', 'BORROWED', 'ON_DISPLAY', NULL, 3, 2, 1, 5),
  ('AO0012', 'Torso of Flight', 'Cubist bronze torso built from angular planes.', 1925,
    'SCULPTURE', 'PERMANENT', 'ON_LOAN', 7, 7, 6, 5, NULL),
  ('AO0013', 'Statue of Athena', 'Marble statue of the goddess Athena in armour.', -325,
    'STATUE', 'PERMANENT', 'ON_DISPLAY', NULL, 2, 1, 1, 3),
  ('AO0014', 'Kouros Figure', 'Standing marble youth in the archaic Greek manner.', -540,
    'STATUE', 'PERMANENT', 'ON_DISPLAY', NULL, 2, 1, 1, 3),
  ('AO0015', 'Youth with a Lyre', 'Renaissance marble of a young musician.', 1512, 'STATUE',
    'PERMANENT', 'ON_DISPLAY', 8, 1, 3, 1, 4),
  ('AO0016', 'Saint Michael and the Dragon',
    'Bronze statue of the archangel defeating the dragon.', 1520, 'STATUE', 'BORROWED',
    'ON_DISPLAY', 8, 1, 3, 1, 4),
  ('AO0017', 'Seated Bodhisattva', 'Gilded wooden seated figure from a Japanese temple.', 1200,
    'STATUE', 'PERMANENT', 'ON_DISPLAY', NULL, 8, 2, 1, 7),
  ('AO0018', 'The Founder (Monument Maquette)', 'Bronze maquette for a civic monument.', 1958,
    'STATUE', 'BORROWED', 'RETURNED', 6, 6, 6, 2, NULL),
  ('AO0019', 'Fishing Boats Beneath the Wave',
    'Colour woodblock print of boats under a towering wave.', 1831, 'OTHER', 'PERMANENT',
    'ON_DISPLAY', 9, 8, 5, 8, 7),
  ('AO0020', 'Moonlit Ferry at Sumida', 'Night-time woodblock print of a river ferry.', 1835,
    'OTHER', 'BORROWED', 'ON_DISPLAY', 9, 8, 5, 8, 7),
  ('AO0021', 'Mill Street, 1932', 'Silver gelatin photograph of a granite-lined city street.',
    1932, 'OTHER', 'PERMANENT', 'ON_DISPLAY', 10, 6, 6, 2, 8),
  ('AO0022', 'Harbour Cranes at Dusk', 'Photograph of harbour cranes silhouetted at dusk.', 1938,
    'OTHER', 'PERMANENT', 'ON_DISPLAY', 10, 6, 6, 2, 8),
  ('AO0023', 'Study for The Sacrifice of Isaac',
    'Red chalk drawing, a preparatory study for a lost altarpiece.', 1636, 'OTHER',
    'PERMANENT', 'IN_STORE', 1, 1, 4, 3, NULL),
  ('AO0024', 'Lotus Pond at Night', 'Abstract lithograph of lotus leaves in dark water.', 1974,
    'OTHER', 'PERMANENT', 'ON_LOAN', 4, 3, 6, 6, NULL);

-- Painting (6 rows)
INSERT INTO Painting (objectID, paintingMedium, surfaceMaterialID) VALUES
  ('AO0001', 'Oil', 1),
  ('AO0002', 'Oil', 1),
  ('AO0003', 'Oil', 1),
  ('AO0004', 'Acrylic', 1),
  ('AO0005', 'Oil', 3),
  ('AO0006', 'Watercolour', 2);

-- Sculpture (6 rows)
INSERT INTO Sculpture (objectID, materialID, heightCm, weightKg) VALUES
  ('AO0007', 3, 120.00, 85.50),
  ('AO0008', 5, 64.00, 40.00),
  ('AO0009', 6, 150.00, 620.00),
  ('AO0010', 4, 38.00, 55.00),
  ('AO0011', 6, 140.00, 480.00),
  ('AO0012', 5, 95.00, 70.00);

-- Statue (6 rows)
INSERT INTO Statue (objectID, materialID, heightCm, weightKg) VALUES
  ('AO0013', 4, 182.00, 410.00),
  ('AO0014', 4, 195.00, 380.00),
  ('AO0015', 4, 160.00, 290.00),
  ('AO0016', 5, 110.00, 150.00),
  ('AO0017', 3, 98.00, 60.00),
  ('AO0018', 5, 85.00, 120.00);

-- OtherObject (6 rows)
INSERT INTO OtherObject (objectID, otherType) VALUES
  ('AO0019', 'Woodblock print'),
  ('AO0020', 'Woodblock print'),
  ('AO0021', 'Photograph'),
  ('AO0022', 'Photograph'),
  ('AO0023', 'Chalk drawing'),
  ('AO0024', 'Lithograph');

-- PermanentObject (18 rows)
INSERT INTO PermanentObject (objectID, acquisitionDate, acquisitionCost) VALUES
  ('AO0001', '2008-03-14', 125000.00),
  ('AO0002', '2011-09-02', 98000.00),
  ('AO0003', '2003-06-20', 210000.00),
  ('AO0004', '2015-11-30', 54000.00),
  ('AO0007', '1999-05-11', 76000.00),
  ('AO0008', '2001-02-19', 48000.00),
  ('AO0009', '2013-10-08', 88000.00),
  ('AO0010', '1987-07-23', 15000.00),
  ('AO0012', '2006-04-04', 132000.00),
  ('AO0013', '1992-09-01', 340000.00),
  ('AO0014', '1992-09-01', 295000.00),
  ('AO0015', '2005-03-17', 410000.00),
  ('AO0017', '2010-12-12', 185000.00),
  ('AO0019', '2014-01-25', 32000.00),
  ('AO0021', '2017-06-09', 2800.00),
  ('AO0022', '2017-06-09', 3100.00),
  ('AO0023', '2003-06-20', 18000.00),
  ('AO0024', '2016-02-15', 7500.00);

-- BorrowedObject (6 rows)
INSERT INTO BorrowedObject (objectID) VALUES
  ('AO0005'),
  ('AO0006'),
  ('AO0011'),
  ('AO0016'),
  ('AO0018'),
  ('AO0020');

-- Borrowing (7 rows)
INSERT INTO Borrowing (objectID, dateBorrowed, museumID, dateDue, dateReturned) VALUES
  ('AO0005', '2026-03-01', 1, '2027-03-01', NULL),
  ('AO0006', '2025-02-01', 4, '2025-08-01', '2025-07-28'),
  ('AO0006', '2026-05-01', 4, '2027-05-01', NULL),
  ('AO0011', '2026-01-15', 2, '2027-01-15', NULL),
  ('AO0016', '2026-04-10', 6, '2027-04-10', NULL),
  ('AO0018', '2025-06-01', 6, '2026-06-01', '2026-05-28'),
  ('AO0020', '2026-09-01', 7, '2027-06-30', NULL);

-- Lending (7 rows)
INSERT INTO Lending (objectID, dateLent, museumID, dateDue, dateReturned) VALUES
  ('AO0012', '2026-09-15', 3, '2027-03-15', NULL),
  ('AO0024', '2026-10-01', 7, '2027-01-31', NULL),
  ('AO0003', '2024-04-01', 2, '2024-10-01', '2024-09-28'),
  ('AO0007', '2025-01-10', 3, '2025-07-10', '2025-07-09'),
  ('AO0015', '2025-05-05', 6, '2025-11-05', '2025-11-01'),
  ('AO0019', '2025-09-01', 7, '2026-02-28', '2026-02-25'),
  ('AO0001', '2023-06-01', 5, '2023-12-01', '2023-11-30');

-- ExhibitionFeature (9 rows)
INSERT INTO ExhibitionFeature (exhibitionID, featureType, featureValue) VALUES
  (7, 'STYLE', 'Impressionist'),
  (8, 'CATEGORY', 'STATUE'),
  (8, 'ORIGIN', 'Greek'),
  (9, 'EPOCH', 'Baroque'),
  (9, 'ORIGIN', 'Dutch'),
  (10, 'STYLE', 'Abstract'),
  (11, 'CATEGORY', 'OTHER'),
  (11, 'ORIGIN', 'Japanese'),
  (12, 'ARTIST', 'Giulia Marchetti');

-- ExhibitionObject (14 rows)
INSERT INTO ExhibitionObject (exhibitionID, objectID) VALUES
  (7, 'AO0002'),
  (7, 'AO0006'),
  (8, 'AO0010'),
  (8, 'AO0013'),
  (8, 'AO0014'),
  (8, 'AO0015'),
  (9, 'AO0001'),
  (9, 'AO0005'),
  (10, 'AO0004'),
  (10, 'AO0009'),
  (11, 'AO0019'),
  (11, 'AO0020'),
  (12, 'AO0003'),
  (12, 'AO0023');

-- ReplicaSale (10 rows)
INSERT INTO ReplicaSale (exhibitionID, objectID, unitPrice, quantitySold) VALUES
  (7, 'AO0002', 45.00, 120),
  (7, 'AO0006', 30.00, 64),
  (8, 'AO0013', 85.00, 40),
  (8, 'AO0014', 85.00, 33),
  (8, 'AO0015', 120.00, 25),
  (9, 'AO0001', 40.00, 150),
  (9, 'AO0005', 40.00, 96),
  (10, 'AO0004', 55.00, 18),
  (11, 'AO0019', 25.00, 0),
  (12, 'AO0003', 60.00, 0);

-- LoyalVisitor (8 rows)
INSERT INTO LoyalVisitor (loyaltyNo, firstName, lastName, address, email, phone, joinDate) VALUES
  ('LM1001', 'Catherine', 'Bell', '22 Rosemount Place, Aberdeen AB25 2QX',
    'catherine.bell@example.org', '07700 900101', '2019-03-12'),
  ('LM1002', 'James', 'Okoro', '8 Holburn Court, Aberdeen AB10 6QQ', 'james.okoro@example.org',
    '07700 900102', '2020-01-20'),
  ('LM1003', 'Sophie', 'Laurent', '15 Ferryhill Road, Aberdeen AB11 6QN',
    'sophie.laurent@example.org', NULL, '2018-09-05'),
  ('LM1004', 'Ravi', 'Patel', '3 Westburn Drive, Aberdeen AB25 2QZ', 'ravi.patel@example.org',
    '07700 900104', '2021-06-14'),
  ('LM1005', 'Mei Lin', 'Chen', '41 Cults Avenue, Aberdeen AB15 9QP', 'meilin.chen@example.org',
    '07700 900105', '2022-02-28'),
  ('LM1006', 'Angus', 'Murray', '6 Kingswells Brae, Aberdeen AB15 8QT',
    'angus.murray@example.org', NULL, '2017-11-09'),
  ('LM1007', 'Elena', 'Rossi', '19 Seaton Walk, Aberdeen AB24 1QS', 'elena.rossi@example.org',
    '07700 900107', '2023-04-03'),
  ('LM1008', 'David', 'Walker', '27 Bridge of Don Road, Aberdeen AB23 8QH', NULL, '07700 900108',
    '2024-08-17');

-- VisitorPreference (16 rows)
INSERT INTO VisitorPreference (loyaltyNo, featureType, featureValue) VALUES
  ('LM1001', 'STYLE', 'Impressionist'),
  ('LM1001', 'ORIGIN', 'French'),
  ('LM1002', 'CATEGORY', 'STATUE'),
  ('LM1002', 'ORIGIN', 'Greek'),
  ('LM1003', 'EPOCH', 'Baroque'),
  ('LM1003', 'ORIGIN', 'Dutch'),
  ('LM1003', 'ARTIST', 'Giulia Marchetti'),
  ('LM1004', 'STYLE', 'Abstract'),
  ('LM1004', 'CATEGORY', 'OTHER'),
  ('LM1005', 'ORIGIN', 'Japanese'),
  ('LM1005', 'CATEGORY', 'OTHER'),
  ('LM1006', 'ARTIST', 'Margaret Ellison'),
  ('LM1006', 'CATEGORY', 'SCULPTURE'),
  ('LM1007', 'STYLE', 'Impressionist'),
  ('LM1008', 'EPOCH', 'Modern'),
  ('LM1008', 'STYLE', 'Abstract');

-- Invitation (11 rows)
INSERT INTO Invitation (loyaltyNo, exhibitionID, sentDate, channel, response) VALUES
  ('LM1001', 7, '2026-02-10', 'EMAIL', 'ACCEPTED'),
  ('LM1007', 7, '2026-02-10', 'EMAIL', 'DECLINED'),
  ('LM1002', 8, '2026-04-28', 'POST', 'ACCEPTED'),
  ('LM1006', 8, '2026-04-28', 'EMAIL', 'DECLINED'),
  ('LM1003', 9, '2026-08-20', 'EMAIL', 'ACCEPTED'),
  ('LM1008', 9, '2026-08-20', 'SMS', 'DECLINED'),
  ('LM1001', 9, '2026-08-20', 'POST', 'DECLINED'),
  ('LM1004', 10, '2026-09-28', 'EMAIL', 'ACCEPTED'),
  ('LM1008', 10, '2026-09-28', 'SMS', 'ACCEPTED'),
  ('LM1005', 11, '2026-10-25', 'EMAIL', 'PENDING'),
  ('LM1004', 11, '2026-10-25', 'EMAIL', 'PENDING');

-- Staff (16 rows)
INSERT INTO Staff (staffID, firstName, lastName, jobTitle, staffType, phone, email, hireDate) VALUES
  (1, 'Eleanor', 'Whitfield', 'Chief Curator', 'CURATOR', '0131 496 0101',
    'eleanor.whitfield@museum.example', '2009-02-02'),
  (2, 'Marcus', 'Okafor', 'Curator of Paintings', 'CURATOR', '0131 496 0102',
    'marcus.okafor@museum.example', '2014-09-15'),
  (3, 'Sofia', 'Lindqvist', 'Curator of Sculpture', 'CURATOR', '0131 496 0103',
    'sofia.lindqvist@museum.example', '2016-04-04'),
  (4, 'Daniel', 'Ruiz', 'Senior Curator of Sculpture', 'CURATOR', '0131 496 0104',
    'daniel.ruiz@museum.example', '2011-01-10'),
  (5, 'Aisha', 'Rahman', 'Curator of Antiquities', 'CURATOR', '0131 496 0105',
    'aisha.rahman@museum.example', '2018-06-18'),
  (6, 'Tom', 'Henderson', 'Curator of Statuary', 'CURATOR', '0131 496 0106',
    'tom.henderson@museum.example', '2012-10-01'),
  (7, 'Yuki', 'Matsuda', 'Curator of Prints and Photography', 'CURATOR', '0131 496 0107',
    'yuki.matsuda@museum.example', '2019-03-25'),
  (8, 'Grace', 'Campbell', 'Curator of Works on Paper', 'CURATOR', NULL,
    'grace.campbell@museum.example', '2015-05-11'),
  (9, 'Hamish', 'Gordon', 'Gallery Supervisor', 'SUPERVISOR', '07700 900209',
    'hamish.gordon@museum.example', '2017-02-06'),
  (10, 'Isabelle', 'Moreau', 'Gallery Supervisor', 'SUPERVISOR', '07700 900210',
    'isabelle.moreau@museum.example', '2019-07-22'),
  (11, 'Kwame', 'Mensah', 'Senior Gallery Supervisor', 'SUPERVISOR', '07700 900211',
    'kwame.mensah@museum.example', '2013-11-04'),
  (12, 'Rhona', 'MacLeod', 'Gallery Supervisor', 'SUPERVISOR', '07700 900212',
    'rhona.macleod@museum.example', '2021-01-18'),
  (13, 'Oliver', 'Grant', 'Exhibition Supervisor', 'SUPERVISOR', '07700 900213',
    'oliver.grant@museum.example', '2016-08-30'),
  (14, 'Nadia', 'Petrov', 'Gallery Supervisor', 'SUPERVISOR', NULL,
    'nadia.petrov@museum.example', '2022-05-09'),
  (15, 'Fraser', 'Duncan', 'Head of Security', 'OTHER', '0131 496 0115',
    'fraser.duncan@museum.example', '2010-03-15'),
  (16, 'Leila', 'Hosseini', 'Visitor Services Manager', 'OTHER', '0131 496 0116',
    'leila.hosseini@museum.example', '2018-01-08');

-- Curator (8 rows)
INSERT INTO Curator (staffID, specialisation, maxObjects) VALUES
  (1, 'PAINTING', 20),
  (2, 'PAINTING', 8),
  (3, 'SCULPTURE', 6),
  (4, 'SCULPTURE', 20),
  (5, 'STATUE', 6),
  (6, 'STATUE', 10),
  (7, 'OTHER', 12),
  (8, 'OTHER', 20);

-- Supervisor (6 rows)
INSERT INTO Supervisor (staffID) VALUES
  (9),
  (10),
  (11),
  (12),
  (13),
  (14);

-- Maintains (26 rows)
INSERT INTO Maintains (staffID, objectID, assignedDate) VALUES
  (1, 'AO0001', '2018-01-15'),
  (1, 'AO0003', '2018-01-15'),
  (2, 'AO0003', '2019-02-01'),
  (2, 'AO0002', '2019-02-01'),
  (2, 'AO0004', '2019-02-01'),
  (2, 'AO0005', '2026-03-01'),
  (1, 'AO0006', '2026-05-01'),
  (3, 'AO0007', '2017-05-10'),
  (3, 'AO0008', '2017-05-10'),
  (3, 'AO0009', '2017-05-10'),
  (4, 'AO0009', '2013-10-08'),
  (4, 'AO0010', '2012-03-01'),
  (4, 'AO0011', '2026-01-15'),
  (3, 'AO0012', '2017-05-10'),
  (5, 'AO0013', '2018-09-03'),
  (6, 'AO0013', '2012-10-01'),
  (5, 'AO0014', '2018-09-03'),
  (5, 'AO0015', '2018-09-03'),
  (6, 'AO0016', '2026-04-10'),
  (6, 'AO0017', '2012-10-01'),
  (7, 'AO0019', '2019-04-01'),
  (7, 'AO0020', '2026-09-01'),
  (8, 'AO0021', '2017-06-12'),
  (8, 'AO0022', '2017-06-12'),
  (7, 'AO0023', '2019-04-01'),
  (8, 'AO0024', '2016-02-15');

-- SupervisesGallery (10 rows)
INSERT INTO SupervisesGallery (staffID, galleryID, fromDate, toDate) VALUES
  (9, 1, '2025-01-06', NULL),
  (10, 2, '2025-01-06', NULL),
  (11, 3, '2024-09-01', NULL),
  (12, 4, '2025-03-03', NULL),
  (12, 5, '2025-03-03', NULL),
  (14, 6, '2025-06-02', NULL),
  (13, 7, '2025-06-02', '2026-03-31'),
  (10, 7, '2026-04-01', NULL),
  (11, 8, '2025-01-06', NULL),
  (9, 2, '2023-05-01', '2024-12-31');

-- SupervisesFeatured (10 rows)
INSERT INTO SupervisesFeatured (staffID, exhibitionID, allocatedOn) VALUES
  (13, 7, '2026-02-20'),
  (9, 7, '2026-02-25'),
  (11, 8, '2026-05-01'),
  (12, 8, '2026-05-01'),
  (10, 9, '2026-08-25'),
  (13, 9, '2026-08-25'),
  (14, 10, '2026-10-01'),
  (13, 10, '2026-10-01'),
  (11, 11, '2027-02-01'),
  (9, 12, '2027-02-15');

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
