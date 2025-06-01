-- DragSystem.lua
-- This system has been replaced with DragDetector-based physics dragging
-- The functionality is now handled directly in BaseClass.lua

local DragSystem = {}

-- Placeholder functions for backward compatibility
function DragSystem.init()
	print("DragSystem: Using DragDetector-based physics dragging instead")
end

function DragSystem.cleanup()
	-- No cleanup needed
end

function DragSystem.trackObject(object)
	-- Objects are now automatically draggable via DragDetector
	return true
end

function DragSystem.untrackObject(object)
	-- No tracking needed
	return true
end

function DragSystem.cleanupDestroyedObjects()
	-- No cleanup needed
	return 0
end

function DragSystem.getObjectFromInstance(instance)
	-- This functionality is now handled elsewhere
	return nil
end

function DragSystem.hasTrackedObjects()
	-- Always return true for compatibility
	return true
end

function DragSystem.getTrackedObjects()
	-- Return empty table for compatibility
	return {}
end

function DragSystem.setSplittingActive(active)
	-- No longer needed
end

function DragSystem.isSlicingActive()
	-- Always return false
	return false
end

return DragSystem
