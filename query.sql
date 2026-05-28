CONSTRAINT:
CREATE CONSTRAINT UniqueBadgesIdConstraint FOR (b:Badge) REQUIRE b.id IS 
UNIQUE; 

CREATE CONSTRAINT UniqueCommentIdConstraint FOR (c:Comment) REQUIRE c.id IS 
UNIQUE; 

CREATE CONSTRAINT UniqueAnswerIdConstraint FOR (a:Answer) REQUIRE a.id IS 
UNIQUE; 

CREATE CONSTRAINT UniqueQuestionIdConstraint FOR (q:Question) REQUIRE q.id IS 
UNIQUE; 

CREATE CONSTRAINT UniqueUserIdConstraint FOR (u:User) REQUIRE u.id IS 
UNIQUE;



Load Answer:
CALL apoc.periodic.iterate(
"LOAD CSV WITH HEADERS FROM 'file:///answers.csv' AS row
WITH toInteger(row.id) AS answerId, datetime(row.creation_date) AS creationDate,
datetime(row.last_activity_date) AS lastActivityDate, 
CASE row.last_editor_user_id WHEN 'NaN' THEN null ELSE toInteger(row.last_editor_user_id) END AS lastEditorUserId,
toInteger(row.owner_user_id) AS ownerUserId, toInteger(row.parent_id) AS parentId,
toInteger(row.post_type) AS postType, toInteger(row.score) AS score
MERGE (a:Answer {answerId: answerId})
SET a.creationDate = creationDate, a.lastActivityDate = lastActivityDate,
    a.lastEditorUserId = lastEditorUserId, a.ownerUserId = ownerUserId,
    a.parentId = parentId, a.postType = postType, a.score = score
RETURN a, answerId",
"RETURN a",
{batchSize:100, parallel:true});



Load Comment:
CALL apoc.periodic.iterate(
"LOAD CSV WITH HEADERS FROM 'file:///comments.csv' AS row
WITH toInteger(row.id) AS commentId, datetime(row.creation_date) AS creationDate,
toInteger(row.score) AS score, toInteger(row.post_id) AS postId,
toInteger(row.user_id) AS userId
MERGE (c:Comment {commentId: commentId})
SET c.creationDate = creationDate, c.score = score,
    c.postId = postId, c.userId = userId
RETURN c, commentId",
"RETURN c",
{batchSize:100, parallel:true});



Load Badge:
CALL apoc.periodic.iterate(
"LOAD CSV WITH HEADERS FROM 'file:///badges.csv' AS row
WITH toInteger(row.id) AS badgeId, row.name AS name,
datetime(row.date) AS date, toInteger(row.user_id) AS userId
MERGE (b:Badge {badgeId: badgeId})
SET b.name = name, b.date = date, b.userId = userId
RETURN b, badgeId",
"RETURN b",
{batchSize:100, parallel:true});


User Posts Questions:
MATCH (u:User), (q:Question)
WHERE u.userId = q.ownerUserId
MERGE (u)-[rel:POSTS]->(q)
RETURN count(rel);


Users Post Answers:
MATCH (u:User), (a:Answer)
WHERE u.userId = a.ownerUserId
MERGE (u)-[rel:POSTS]->(a)
RETURN count(rel);


Users Create Comments:
MATCH (u:User), (c:Comment)
WHERE u.userId = c.userId
MERGE (u)-[rel:CREATES]->(c)
RETURN count(rel);


Users Earn Badges:
MATCH (u:User), (b:Badge)
WHERE u.userId = b.userId
MERGE (u)-[rel:EARNS]->(b)
RETURN count(rel);


Index for commentID:
CREATE INDEX CommentIdIndex IF NOT EXISTS FOR (c:Comment) ON (c.commentId);

Index for badgeID:
CREATE INDEX BadgeNameIndex IF NOT EXISTS FOR (b:Badge) ON (b.name);

Index for answerID:
CREATE INDEX AnswerIdIndex IF NOT EXISTS FOR (a:Answer) ON (a.answerId);


Q1
MATCH (u:User), (b:Badge), (q:Question)
WHERE datetime(b.date) > datetime("2020-01-01T00:00:00.000Z")
  AND b.name = "Nice Question"
  AND (u)-[:EARNS]->(b)
  AND (u)-[:POSTS]->(q)
RETURN 
    u.userId AS userId,
    u.displayName AS displayName,
    b.name AS badgeName,
    collect(b.date) AS badgeAwardedDate,
    q.questionId AS questionId,
    q.title AS questionTitle


Q2
MATCH (u:User), (b:Badge),(q:Question), (c:Comment)
WHERE datetime(b.date) > datetime("2020-01-01T00:00:00.000Z")
  AND b.name = "Nice Question"
  AND c.postId = q.questionId
  AND (u)-[:EARNS]->(b)
  AND (u)-[:POSTS]->(q)
  AND (u)-[:CREATES]->(c)
RETURN 
    u.userId AS userId,
    u.displayName AS displayName,
    b.name AS badgeName,
    collect(DISTINCT b.date) AS badgeAwardedDate,
    c.postId AS questionId,
    q.title AS questionTitle,
    collect(DISTINCT c.commentId) AS commentId;


Q3
MATCH (u:User), (b:Badge),(q:Question), (a:Answer)
WHERE b.name = "Inquisitive"
  AND (u)-[:EARNS]->(b)
  AND (u)-[:POSTS]->(q)
  AND q.acceptedAnswerId IS NOT NULL
  AND a.answerId = q.acceptedAnswerId
RETURN 
    u.userId AS userId,
    u.displayName AS displayName,
    b.name AS badgeName,
    q.questionId AS questionId,
    q.title AS questionTitle,
    q.acceptedAnswerId AS acceptedAnswerId


CHECK Q3 eg
MATCH (a:Answer{answerId:833082}) RETURN a;

Part 3 :
CREATE CONSTRAINT collectionIDConstraint IF NOT EXISTS FOR (c:Collection) REQUIRE c.collectionID IS UNIQUE;

LOAD CSV WITH HEADERS FROM 'file:///collections.csv' AS row
MERGE (c:Collection {collectionID: toInteger(row.collectionID)})
ON CREATE SET
    c.collectionTitle = row.collectionTitle,
    c.creationDate = datetime(row.creation_date),
    c.ownerUserId = toInteger(row.owner_user_id),
    c.tags = row.tags,
    c.questionCount = toInteger(row.question_count);


LOAD CSV WITH HEADERS FROM 'file:///collections_details.csv' AS row
MATCH (q:Question {questionId: toInteger(row.questionId)}),
      (c:Collection {collectionID: toInteger(trim(row.collectionID))})
MERGE (q)-[:BELONGS_TO]->(c);




MATCH (a:Answer), (q:Question)
WHERE a.parentId = q.questionId
MERGE (a)-[:ANSWERS]->(q);



MATCH (c:Comment), (q:Question)
WHERE c.postId = q.questionId
MERGE (c)-[:COMMENTS_ON]->(q);



MATCH (c:Comment), (a:Answer)
WHERE c.postId = a.answerId
MERGE (c)-[:COMMENTS_ON]->(a);

