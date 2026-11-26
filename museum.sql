-- Our father, who art in heaven
CREATE DATABASE IF NOT EXISTS `museum`; 
-- Artist Table
CREATE TABLE IF NOT EXISTS `Artist`(
	`artistIDRaw` INT AUTO_INCREMENT UNIQUE NOT NULL,
	`artistID` varchar(6)
		GENERATED ALWAYS AS (
			CONCAT('AT', LPAD(artistIDRaw, 4, '0'))
		) STORED PRIMARY KEY NOT NULL,
    `fName` varchar(20) NOT NULL,
    `lName` varchar(20) NOT NULL,
    `dateBorn` DATE,
    `dateDied` DATE,
    `countryOfOrigin` varchar(20),
    `epoch` varchar(20),
    `mainStyle` varchar(20),
    `description` varchar(256)
);

--  Artwork Table
CREATE TABLE IF NOT EXISTS `Artwork`(
    `ArtworkIDRaw` INT AUTO_INCREMENT UNIQUE NOT NULL,
    `ArtworkID` varchar(6)
		GENERATED ALWAYS AS (
			CONCAT('AO', LPAD(ArtworkIDRaw, 4, '0'))
		) STORED PRIMARY KEY NOT NULL,
    `title` varchar(20) NOT NULL,
    `description` varchar(256),
    `yearCreated` int(4) NOT NULL,
    `artist` varchar(41) NOT NULL,
    FOREIGN KEY (artist) REFERENCES Artist(name),
    `originCountryCulture` varchar(20) NOT NULL,
    `epoch` varchar(20) NOT NULL
);




CREATE TABLE IF NOT EXISTS `Museum` (
	`museumIDRaw` INT AUTO_INCREMENT UNIQUE NOT NULL,
	`museumID` varchar(6)
			GENERATED ALWAYS AS (
				CONCAT('MU', LPAD(museumIDRaw, 4, '0'))
			) STORED PRIMARY KEY NOT NULL,
    `museumName` varchar(20) NOT NULL,
    `description` varchar(256),
    `address` varchar(40) UNIQUE NOT NULL,
    `phone` int(11) NOT NULL,
    `currentContact` varchar(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS `Borrowed`(
	`museumID` varchar(20) NOT NULL,
    `ArtworkID` varchar(6) NOT NULL,
    FOREIGN KEY (museumID) REFERENCES Museum(museumID),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `dateBorrowed` DATE NOT NULL,
    `dateToReturn` DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS `Permanent` (
    `ArtworkID` varchar(6) NOT NULL,
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `dateAcquired` DATE NOT NULL,
    `status` ENUM('On Display','On Loan','Under Restoration','In Store') NOT NULL
);

CREATE TABLE IF NOT EXISTS `loan`(
	`museumID` varchar(20) NOT NULL,
    `ArtworkID` varchar(6) NOT NULL,
    FOREIGN KEY (museumID) REFERENCES Museum(museumID),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `loanDate` DATE NOT NULL,
    `loanDueDate` DATE NOT NULL
);

-- Artwork Type Tables
CREATE TABLE IF NOT EXISTS `Painting` (
    `ArtworkID` varchar(6) NOT NULL,
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `material` varchar(20),
    `style` varchar(20)
);

CREATE TABLE IF NOT EXISTS `Sculpture` (
    `ArtworkID` varchar(6) NOT NULL,
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `material` varchar(20),
    `height` float,
    `weight` int(3),
    `style` varchar(20)
);

CREATE TABLE IF NOT EXISTS `Statue` (
    `ArtworkID` varchar(6) NOT NULL,
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `material` varchar(20),
    `height` float,
    `weight` int(2),
    `style` varchar(20)
);

CREATE TABLE IF NOT EXISTS `OtherArtwork` (
    `ArtworkID` varchar(6) NOT NULL,
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `style` varchar(20)
);

-- Staff Tables
CREATE TABLE IF NOT EXISTS  `Staff`(
	`staffIDRaw` INT AUTO_INCREMENT UNIQUE NOT NULL,
    `staffID` varchar(6) 
		GENERATED ALWAYS AS (
			CONCAT('SM', LPAD(staffIDRaw, 4, '0'))
		) STORED PRIMARY KEY NOT NULL,
    `fName` varchar(20) NOT NULL,
    `lName` varchar(20) NOT NULL,
    `phone` int(11) NOT NULL,
    `hireDate` DATE NOT NULL,
    `salary` int(6) NOT NULL,
    `artType` ENUM('Painting','Sculpture','Statue','Other') NOT NULL,
    `supervisor` boolean
);


-- Exhibition/Gallery Tables

CREATE TABLE IF NOT EXISTS `Gallery`(
	`galleryIDRaw` INT AUTO_INCREMENT UNIQUE NOT NULL,
    `galleryID` varchar(6) 
		GENERATED ALWAYS AS (
			CONCAT('GA', LPAD(galleryIDRaw, 4, '0'))
		) STORED PRIMARY KEY NOT NULL,
    `artworkID` varchar(6) NOT NULL,
    `staffID` varchar(6) NOT NULL,
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    FOREIGN KEY (staffID) REFERENCES Staff(staffID),
    `assignedDate` DATE NOT NULL,
    `name` varchar(20) NOT NULL,
    `location` varchar(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS `Exhibition`(
	`exhibitionIDRaw` INT AUTO_INCREMENT UNIQUE NOT NULL,
    `exhibitionID` varchar(6) 
		GENERATED ALWAYS AS (
			CONCAT('EX', LPAD(exhibtionIDRaw, 4, '0'))
		) STORED
    PRIMARY KEY NOT NULL,
    `title` varchar(20)
);

CREATE TABLE IF NOT EXISTS `FeaturedExhibition`(
	`exhibitionID` varchar(6) NOT NULL,
    FOREIGN KEY (exhibitionID) REFERENCES Exhibition(exhibitionID),
    `startDate` DATE NOT NULL,
    `endDate` DATE NOT NULL,
    `featureType` varchar(20) NOT NULL,
    `featureValue` int(7) NOT NULL
);

CREATE TABLE IF NOT EXISTS `ReplicaSale`(
`exhibitionID` varchar(6) NOT NULL,
    FOREIGN KEY (exhibitionID) REFERENCES Exhibition(exhibitionID),
    `unitPrice` int(5) NOT NULL,
    `quantitySold` int(5)
);

-- Visitor Tables
CREATE TABLE IF NOT EXISTS `LoyalVisitor`(
	`LoyaltyNoRaw` INT AUTO_INCREMENT UNIQUE NOT NULL,
    `LoyaltyNo` varchar(6) 
		GENERATED ALWAYS AS (
			CONCAT('LM', LPAD(LoyaltyIDRaw, 4, '0'))
		) STORED PRIMARY KEY NOT NULL,
    `fName` varchar(20) NOT NULL,
    `lName` varchar(20) NOT NULL,
    `address` varchar(40) NOT NULL,
    `email` varchar(20) NOT NULL,
	`featureTypePref` varchar(20)
);

CREATE TABLE IF NOT EXISTS `Invitation`(
	`LoyaltyNo` varchar(6) NOT NULL,
    `email` varchar(20) NOT NULL,
	`exhibitonID` varchar(6) NOT NULL,
    FOREIGN KEY (LoyaltyNo) REFERENCES LoyalVisitor(LoyaltyNo),
    FOREIGN KEY (email) REFERENCES LoyalVisitor(email),
    FOREIGN KEY (exhibitionID) REFERENCES Exhibition(exhibitionID),
    `dateSent` DATE NOT NULL
);