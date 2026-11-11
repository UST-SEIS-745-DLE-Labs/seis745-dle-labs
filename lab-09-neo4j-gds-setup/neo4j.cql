RETURN gds.version();
CALL gds.list();

MATCH (a:Actor)-[r:ACTED_IN]->(m:Movie) RETURN a,m

MATCH (a:Actor)-[*1..2]-(b:Actor|Movie)
WHERE a.name = 'Kevin Bacon'
RETURN a,b

MATCH (a:Actor)-[*1..3]-(b:Actor|Movie)
WHERE a.name = 'Kevin Bacon'
RETURN a,b


MATCH (a:Actor)-[r:ACTED_IN]->(m:Movie)
RETURN gds.graph.project(
    'movies', a, m,
    {
         sourceNodeLabels: labels(a),
         targetNodeLabels: labels(m),
         relationshipType: type(r),
         relationshipProperties: { relationship_id: id(r) } 
    }
)

CALL gds.wcc.write.estimate('movies', { writeProperty: 'component' })
YIELD nodeCount, relationshipCount, bytesMin, bytesMax, requiredMemory

CALL gds.wcc.stats('movies')

CALL gds.wcc.stream('movies')
YIELD nodeId, componentId
RETURN DISTINCT componentId, COUNT(1) AS num_components
ORDER BY num_components ASC

CALL gds.wcc.write('movies', { writeProperty: 'componentId' })
YIELD nodePropertiesWritten, componentCount;

MATCH (a:Actor)-[r:ACTED_IN]->(m:Movie)
WHERE a.componentId = 912 AND m.componentId = 912
RETURN a, m