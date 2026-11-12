-- =============================================================================
--  CS2019 Assessment 2 : Arts Museum Database
--  Script 4 of 4 : the transaction requirements (T1-T10 from the brief,
--                  T11-T13 added in Task 1).  Replace the example values
--                  (names, IDs, dates) with the ones you need.
-- =============================================================================
USE ArtsMuseumDB;

-- T1. Add a new art object to the permanent collection.
--     Three rows describe one object, so they are written as ONE transaction:
--     if any statement fails, nothing is stored.
START TRANSACTION;
INSERT INTO ArtObject (objectID, title, description, yearCreated, category, ownership,
                       status, artistID, originID, epochID, styleID, galleryID)
VALUES ('AO0025', 'The Reading Room', 'Oil painting of readers in a sunlit library.', 1891,
        'PAINTING', 'PERMANENT', 'IN_STORE', 3, 4, 6, 4, NULL);
INSERT INTO Painting (objectID, paintingMedium, surfaceMaterialID)
VALUES ('AO0025', 'Oil', 1);
INSERT INTO PermanentObject (objectID, acquisitionDate, acquisitionCost)
VALUES ('AO0025', '2026-11-05', 61000.00);
COMMIT;

-- T2. Change the end date of a featured exhibition (the CHECK constraint rejects
--     an end date earlier than the start date).
UPDATE FeaturedExhibition
SET    endDate = '2027-01-31'
WHERE  exhibitionID = (SELECT exhibitionID FROM Exhibition
                       WHERE exhibitionName = 'The Dutch Golden Age');

-- T3. List all the borrowed art objects (with lender, dates and loan state).
SELECT ao.objectID, ao.title, ao.category, mu.museumName AS lender,
       b.dateBorrowed, b.dateDue, b.dateReturned,
       CASE WHEN b.dateReturned IS NULL THEN 'Held now' ELSE 'Returned' END AS loanState
FROM BorrowedObject bo
JOIN ArtObject ao ON ao.objectID = bo.objectID
JOIN Borrowing b  ON b.objectID  = bo.objectID
JOIN Museum mu    ON mu.museumID = b.museumID
ORDER BY ao.objectID, b.dateBorrowed;

-- T4. Count the number of art objects created by a given artist
--     (an artist is identified by name + date born [+ date died]).
SELECT a.artistName, a.dateBorn, COUNT(ao.objectID) AS numberOfObjects
FROM Artist a
LEFT JOIN ArtObject ao ON ao.artistID = a.artistID
WHERE a.artistName = 'Margaret Ellison' AND a.dateBorn = '1903-08-14'
GROUP BY a.artistID, a.artistName, a.dateBorn;

-- T5. Count the art objects per category displayed in the regular exhibition,
--     largest group first (ties in alphabetical order of category).
SELECT ao.category, COUNT(*) AS numberOfObjects
FROM ArtObject ao
JOIN Gallery g           ON g.galleryID = ao.galleryID
JOIN RegularExhibition r ON r.exhibitionID = g.regularExhibitionID
GROUP BY ao.category
ORDER BY numberOfObjects DESC, ao.category;

-- T6. List all the art objects borrowed from a given Arts Friends Circle museum.
SELECT ao.objectID, ao.title, b.dateBorrowed, b.dateDue, b.dateReturned
FROM Museum mu
JOIN Borrowing b  ON b.museumID = mu.museumID
JOIN ArtObject ao ON ao.objectID = b.objectID
WHERE mu.museumName = 'Tay Valley Art Museum'
ORDER BY b.dateBorrowed;

-- T7. List the staff supervising a given featured exhibition.
SELECT s.staffID, s.firstName, s.lastName, s.jobTitle, sf.allocatedOn
FROM SupervisesFeatured sf
JOIN Staff s ON s.staffID = sf.staffID
WHERE sf.exhibitionID = (SELECT exhibitionID FROM Exhibition
                         WHERE exhibitionName = 'Gods and Heroes in Marble')
ORDER BY s.lastName;

-- T8. List all the curators responsible for maintaining a given art object.
SELECT s.staffID, s.firstName, s.lastName, c.specialisation, m.assignedDate
FROM Maintains m
JOIN Curator c ON c.staffID = m.staffID
JOIN Staff s   ON s.staffID = c.staffID
WHERE m.objectID = 'AO0009'
ORDER BY s.lastName;

-- T9. List all featured exhibitions with start and end dates and their loyal
--     visitors (= visitors who were sent an invitation). LEFT JOINs keep
--     exhibitions that have not invited anybody yet.
SELECT e.exhibitionName, fe.startDate, fe.endDate,
       lv.loyaltyNo, CONCAT(lv.firstName, ' ', lv.lastName) AS visitorName
FROM FeaturedExhibition fe
JOIN Exhibition e          ON e.exhibitionID = fe.exhibitionID
LEFT JOIN Invitation i     ON i.exhibitionID = fe.exhibitionID
LEFT JOIN LoyalVisitor lv  ON lv.loyaltyNo   = i.loyaltyNo
ORDER BY fe.startDate, e.exhibitionName, lv.lastName;

-- T10. List the art objects used in a given featured exhibition that were
--      created by a given artist.
SELECT ao.objectID, ao.title, ao.yearCreated
FROM ExhibitionObject eo
JOIN Exhibition e  ON e.exhibitionID = eo.exhibitionID
JOIN ArtObject ao  ON ao.objectID    = eo.objectID
JOIN Artist a      ON a.artistID     = ao.artistID
WHERE e.exhibitionName = 'The Dutch Golden Age'
  AND a.artistName = 'Pieter van der Linden' AND a.dateBorn = '1620-05-21'
ORDER BY ao.objectID;

-- T11 (added). List the permanent objects that are lent out and not yet back.
SELECT ao.objectID, ao.title, mu.museumName AS borrower, l.dateLent, l.dateDue
FROM Lending l
JOIN ArtObject ao ON ao.objectID = l.objectID
JOIN Museum mu    ON mu.museumID = l.museumID
WHERE l.dateReturned IS NULL
ORDER BY l.dateDue;

-- T12 (added). Replica income per featured exhibition.
SELECT e.exhibitionName, SUM(r.quantitySold) AS replicasSold,
       SUM(r.unitPrice * r.quantitySold) AS replicaIncome
FROM ReplicaSale r
JOIN Exhibition e ON e.exhibitionID = r.exhibitionID
GROUP BY e.exhibitionID, e.exhibitionName
ORDER BY replicaIncome DESC;

-- T13 (added). Whom should we invite? Loyal visitors whose preferences match a
--              featured exhibition's features and who have not been invited yet.
SELECT DISTINCT lv.loyaltyNo, lv.firstName, lv.lastName, lv.email, lv.address
FROM FeaturedExhibition fe
JOIN Exhibition e          ON e.exhibitionID = fe.exhibitionID
JOIN ExhibitionFeature ef  ON ef.exhibitionID = fe.exhibitionID
JOIN VisitorPreference vp  ON vp.featureType = ef.featureType
                          AND vp.featureValue = ef.featureValue
JOIN LoyalVisitor lv       ON lv.loyaltyNo = vp.loyaltyNo
WHERE e.exhibitionName = 'Marchetti: A Baroque Life'
  AND NOT EXISTS (SELECT 1 FROM Invitation i
                  WHERE i.loyaltyNo = lv.loyaltyNo AND i.exhibitionID = fe.exhibitionID);
