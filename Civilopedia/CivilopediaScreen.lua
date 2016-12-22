-- ===========================================================================
--	Civilopedia
-- ===========================================================================

-- Include all of the base civilopedia logic.
include("CivilopediaSupport");

-- Now that all of the utility functions have been defined and all of the scaffolding in place...
-- Load all of the Civilopedia pages.
-- These individual files will define the page layouts referenced in the database.
-- By keeping the pages separated from each other and the base logic, modders can quickly add new page layouts
-- or replace existing ones.
include("CivilopediaPage_", true);


-- Initialize the pedia!
Initialize();