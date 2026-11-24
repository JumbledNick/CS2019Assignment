-- Our father, who art in heaven
CREATE DATABASE IF NOT EXISTS `museum`; 

--  Artwork Table
CREATE TABLE IF NOT EXISTS `Artwork`(
    `ArtworkID` varchar(5) PRIMARY KEY,
    `title` varchar(20),
    `description` varchar(256),
    `yearCreated` int(4),
    `originCountryCulture` varchar(20),
    `epoch` varchar(20)
);


-- Artist Table
CREATE TABLE IF NOT EXISTS `Artist`(
    `name` varchar(41) PRIMARY KEY,
    `dateBorn` DATE,
    `dateDied` DATE,
    `countryOfOrigin` varchar(20),
    `epoch` varchar(20),
    `mainStyle` varchar(20),
    `description` varchar(256)
);

CREATE TABLE IF NOT EXISTS `Museum` (
    `museumName` varchar(20) PRIMARY KEY,
    `description` varchar(256),
    `address` varchar(40),
    `phone` int(11),
    `currentContact` varchar(20)
);

CREATE TABLE IF NOT EXISTS `Borrowed`(
	`museumName` varchar(20),
    `ArtworkID` varchar(5),
    FOREIGN KEY (museumName) REFERENCES Museum(museumName),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `dateBorrowed` DATE,
    `dateToReturn` DATE
);

CREATE TABLE IF NOT EXISTS `Permanent` (
    `ArtworkID` varchar(5),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `dateAcquired` DATE,
    `status` varchar(20)
);

CREATE TABLE IF NOT EXISTS `loan`(
	`museumName` varchar(20),
    `ArtworkID` varchar(5),
    FOREIGN KEY (museumName) REFERENCES Museum(museumName),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `loanDate` DATE,
    `loanDueDate` DATE
);

-- Artwork Type Tables
CREATE TABLE IF NOT EXISTS `Painting` (
    `ArtworkID` varchar(5),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `material` varchar(20),
    `style` varchar(20)
);

CREATE TABLE IF NOT EXISTS `Sculpture` (
    `ArtworkID` varchar(5),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `material` varchar(20),
    `height` float,
    `weight` int(2),
    `style` varchar(20)
);

CREATE TABLE IF NOT EXISTS `Statue` (
    `ArtworkID` varchar(5),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `material` varchar(20),
    `height` float,
    `weight` int(2),
    `style` varchar(20)
);

CREATE TABLE IF NOT EXISTS `OtherArtwork` (
    `ArtworkID` varchar(5),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `style` varchar(20)
);

-- Staff Tables
CREATE TABLE IF NOT EXISTS  `Staff`(
    `staffID` varchar(5) PRIMARY KEY,
    `fName` varchar(20),
    `lName` varchar(20),
    `phone` int(11),
    `hireDate` DATE,
    `salary` int(6)
);

CREATE TABLE IF NOT EXISTS `Curator` (
	`staffID` varchar(5),
    `ArtworkID` varchar(5),
    FOREIGN KEY (staffID) REFERENCES Staff(staffID),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    `specialtyType` varchar(20),
    `maxObjects` varchar(20)
);

CREATE TABLE IF NOT EXISTS Supervisor (
	`staffID` varchar(5),
    `galleryID` varchar(5),
    FOREIGN KEY (staffID) REFERENCES Staff(staffID),
    FOREIGN KEY (galleryID) REFERENCES Gallery(galleryID)
);

CREATE TABLE IF NOT EXISTS `Maintenance`(
	`staffID` varchar(5),
    `ArtworkID` varchar(5),
    FOREIGN KEY (ArtworkID) REFERENCES Artwork(ArtworkID),
    FOREIGN KEY (staffID) REFERENCES Staff(staffID),
    `assignedDate` DATE
);
-- Exhibition/Gallery Tables

CREATE TABLE IF NOT EXISTS `Gallery`(
    `galleryID` varchar(7) PRIMARY KEY,
    `name` varchar(20),
    `location` varchar(20)
);

CREATE TABLE IF NOT EXISTS `Exhibition`(
    `exhibitionID` varchar(7) PRIMARY KEY,
    `title` varchar(20)
);

CREATE TABLE IF NOT EXISTS `FeaturedExhibition`(
	`exhibitionID` varchar(7),
    FOREIGN KEY (exhibitionID) REFERENCES Exhibition(exhibitionID),
    `startDate` DATE,
    `endDate` DATE,
    `featureType` varchar(20),
    `featureValue` int(7)
);

CREATE TABLE IF NOT EXISTS `RegularExhibition`(
`exhibitionID` varchar(7),
    FOREIGN KEY (exhibitionID) REFERENCES Exhibition(exhibitionID),
    `title` varchar(20)
);

CREATE TABLE IF NOT EXISTS `ReplicaSale`(
`exhibitionID` varchar(7),
    FOREIGN KEY (exhibitionID) REFERENCES Exhibition(exhibitionID),
    `unitPrice` int(5),
    `quantitySold` int(5)
);

-- Visitor Tables
CREATE TABLE IF NOT EXISTS `LoyalVisitor`(
    `LoyaltyNo` varchar(7) PRIMARY KEY,
    `fName` varchar(20),
    `lName` varchar(20),
    `address` varchar(40),
    `email` varchar(20)
);

CREATE TABLE IF NOT EXISTS `Preference`(
	`LoyaltyNo` varchar(7),
    FOREIGN KEY (LoyaltyNo) REFERENCES LoyalVisitor(LoyaltyNo),
    `featureType` varchar(20),
    `featureValue` varchar(20)
);

CREATE TABLE IF NOT EXISTS `Invitation`(
	`LoyaltyNo` varchar(7),
	`exhibitonID` varchar(5),
    FOREIGN KEY (LoyaltyNo) REFERENCES LoyalVisitor(LoyaltyNo),
    FOREIGN KEY (exhibitionID) REFERENCES Exhibition(exhibitionID),
    `dateSent` DATE
)