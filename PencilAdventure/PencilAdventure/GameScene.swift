//
//  GameScene.swift
//  PencilAdventure
//
//  Created by Jocelyn Harrington on 7/29/14.
//  Copyright (c) 2014 backstopmedia. All rights reserved.
//

import SpriteKit

class GameScene : SKScene, SKPhysicsContactDelegate
{	
	// We draw our sketches directly into this full-screen sprite
	var viewSprite: SKSpriteNode!
	
	// Material properties for sketch rendering
	struct SketchMaterial
	{
		var lineDensity: CGFloat = 3 // lower numbers are more dense
		var minSegmentLength: CGFloat = 3
		var maxSegmentLength: CGFloat = 77
		var pixJitterDistance: CGFloat = 2
		var lineInteriorOverlapJitterDistance: CGFloat = 33
		var lineEndpointOverlapJitterDistance: CGFloat = 9
		var lineOffsetJitterDistance: CGFloat = 5
		var color: UIColor = UIColor.blackColor()
	}
	
    // bg layer
    var background:SKTexture!
    // moving action
    var moving:SKNode!
    // charater
    var pencil:SKSpriteNode!
    
	override func didMoveToView(view: SKView)
	{
        // setup physics
		self.physicsWorld.gravity = CGVector(dx: 0.0, dy: -9.8 )
        self.physicsWorld.contactDelegate = self
        // add moving
        moving = SKNode()
        self.addChild(moving)
        //create bg layer, use a bit of color feature for book demo purpose
        let background = SKTexture(imageNamed: "background")
        background.filteringMode = SKTextureFilteringMode.Nearest
        //parallax background
        let scrollBgSprite = SKAction.moveByX(-background.size().width * 2.0, y: 0, duration: NSTimeInterval(0.1 * background.size().width * 2.0))
        let resetBgSprite = SKAction.moveByX(background.size().width * 2.0, y: 0, duration: 0.0)
        let moveBgSpritesForever = SKAction.repeatActionForever(SKAction.sequence([scrollBgSprite,resetBgSprite]))
        
        for var i:CGFloat = 0; i < 2.0 + self.frame.size.width / ( background.size().width * 2.0 ); ++i {
            let bgSprite = SKSpriteNode(texture: background)
            bgSprite.setScale(2.0)
            bgSprite.color = SKColor(red: 255.0, green: 255.0, blue: 0.0, alpha: 1.0)
            bgSprite.colorBlendFactor = 0.7
			bgSprite.position = CGPoint(x: bgSprite.size.width/2.0, y: bgSprite.size.height/2.0)
            bgSprite.zPosition = -1
            bgSprite.runAction(moveBgSpritesForever)
            moving.addChild(bgSprite)
        }

		//create pencil
        pencil = SKSpriteNode(imageNamed: "pencil")
        pencil.physicsBody = SKPhysicsBody(circleOfRadius: pencil.size.width / 2)
        pencil.physicsBody.dynamic = true
        pencil.position = CGPoint(x:frame.size.width/2, y:frame.size.height/2)
        self.addChild(pencil)
		
		// Attach our sketch nodes to all sprites
		attachSketchNodes(self)
        
		// Create a full-screen viewport
		viewSprite = SKSpriteNode(color: UIColor(red: 0, green: 0, blue: 0, alpha: 0), size: frame.size)
		viewSprite.position = CGPoint(x:frame.size.width/2, y:frame.size.height/2)
		self.addChild(viewSprite)
	}
	
	override func update(currentTime: CFTimeInterval)
	{
		// Draw the scene
		renderScene()
        moving.speed = 1
	}
	
    //TODO: we can add more action later, to keep the demo simple, we use touch to jump for now
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        // touch to jump
        if moving.speed > 0  {
            for touch: AnyObject in touches {
                let location = touch.locationInNode(self)
				pencil.physicsBody.velocity = CGVector(dx: 0, dy: 1)
				pencil.physicsBody.applyImpulse(CGVector(dx: 0, dy: 10))
				
            }
        }
    }
    
	// -------------------------------------------------------------------------------------------------------------------
	
	func attachSketchNodes(node: SKNode)
	{
		for child in node.children as [SKNode]
		{
			// Let's do depth-first traversal so that we don't end up traversing the children we're about to add
			attachSketchNodes(child)

			// Attach shapes to sprites
			if let sprite = child as? SKSpriteNode
			{
				let image = UIImage(named: sprite.name)
				if image != nil
				{
					if let path = ImageTools.vectorizeImage(image)
					{
						// Create a new shape from the path and attach it to this sprite node
						var shape = SKShapeNode(path: path)
						shape.position = CGPoint(x:sprite.position.x, y: frame.size.height - sprite.position.y)
						shape.xScale = sprite.xScale * 0.77 // TODO - why 0.77??
						shape.yScale = sprite.yScale * 0.77 // TODO - why 0.77??
						shape.zRotation = sprite.zRotation
						shape.zPosition = sprite.zPosition
						shape.strokeColor = UIColor.greenColor() //sprite.color
						sprite.addChild(shape)
					}
				}
			}
		}
	}
	
	func renderScene()
	{
		UIGraphicsBeginImageContext(frame.size)
		var ctx = UIGraphicsGetCurrentContext()

		renderNode(ctx, node: self)
		
		var textureImage = UIGraphicsGetImageFromCurrentImageContext()
		viewSprite.texture = SKTexture(image: textureImage)
		
		UIGraphicsEndImageContext()
	}
	
	func renderNode(context: CGContext, node: SKNode)
	{
		for child in node.children as [SKNode]
		{
			// Create a material
			var m = SketchMaterial()
			var drawPath: CGPath? = nil
			
			if let shape = child as? SKShapeNode
			{
				// Set the color
				m.color = shape.strokeColor
				
				// Transform our path
				var xform = createNodeTransform(shape)
				if let path = CGPathCreateCopyByTransformingPath(shape.path, &xform)
				{
					// Get the path elements
					var elements = ConvertPath(path)
					
					// Draw it!
					drawPathToContext(context, pathElements: elements, material: m)
				}
			}
		
			// Recurse into the children
			renderNode(context, node: child)
		}
	}

	func createNodeTransform(node: SKNode) -> CGAffineTransform
	{
		// Transform the path as specified by the sprite
		//
		// Note the order of operations we want to happen are specified in reverse. We want to scale first,
		// then rotate, then translate. If we do these out of order, then we might rotate around a different
		// point (if we've already moved it) or scale the object in the wrong direction (if we've rotated it.)
		var xform = CGAffineTransformIdentity
		xform = CGAffineTransformTranslate(xform, node.position.x, node.position.y)
		xform = CGAffineTransformRotate(xform, node.zRotation)
		xform = CGAffineTransformScale(xform, node.xScale, node.yScale)
		return xform
	}
	
	func drawPathToContext(context: CGContext, pathElements: NSArray!, material: SketchMaterial)
	{
		var path = UIBezierPath()
		path.lineWidth = 1
		
		var startPoint: CGVector? = nil
		var endPoint: CGVector? = nil
		for element in pathElements
		{
			// Starting a new batch of lines?
			if element.elementType == 0
			{
				startPoint = nil;
				endPoint = element.point.toCGVector()
				continue
			}
			else if element.elementType == 1 || element.elementType == 4
			{
				startPoint = endPoint
				endPoint = element.point.toCGVector()
			}
			
			// Make sure we have something to work with
			if startPoint == nil || endPoint == nil
			{
				continue
			}
			
			// The vector that defines our line
			var lineVector = endPoint! - startPoint!
			var lineDir = lineVector.normal
			var lineDirPerp = lineDir.perpendicular()
			
			// Line extension
			var lineP0 = startPoint! - lineDir * CGFloat.randomValue(material.lineEndpointOverlapJitterDistance)
			var lineP1 = endPoint! + lineDir * CGFloat.randomValue(material.lineEndpointOverlapJitterDistance)
			
			// Recalculate our line vector since it has changed
			lineVector = lineP1 - lineP0
			
			// Line length
			var lineLength = lineVector.length
			
			// Break the line up into segments
			var lengthSoFar: CGFloat = 0
			var done = false
			while lengthSoFar < lineLength && !done
			{
				// How far to draw for this segment?
				var segmentLength = material.minSegmentLength + CGFloat.randomValue(material.maxSegmentLength - material.minSegmentLength)
				
				// Don't go past the end of our line
				if segmentLength + lengthSoFar > lineLength
				{
					segmentLength = lineLength - lengthSoFar
					done = true
				}
				
				// Endpoints for this segment
				var segP0 = lineP0 + lineDir * lengthSoFar
				var segP1 = segP0 + lineDir * segmentLength
				
				// Add some overlap
				if lengthSoFar != 0
				{
					var overlap = CGFloat.randomValue(material.lineInteriorOverlapJitterDistance)
					
					// Our interior overlap might extend outside of our line, so we can check here to ensure
					// that doesn't happen
					if overlap > lengthSoFar
					{
						overlap = lengthSoFar
					}
					segP0 -= lineDir * overlap
				}
				
				// Offset them a little, perpendicular to the direction of the line
				segP0 += lineDirPerp * CGFloat.randomValueSigned(material.lineOffsetJitterDistance)
				segP1 += lineDirPerp * CGFloat.randomValueSigned(material.lineOffsetJitterDistance)
				
				// Draw the segment
				addPencilLineToPath(path, startPoint: segP0, endPoint: segP1, material: material)
				
				// Track how much we've drawn so far
				lengthSoFar += segmentLength
			}
			
			startPoint = endPoint
		}
		
		CGContextSetStrokeColorWithColor(context, material.color.CGColor)
		path.stroke()
	}
	
	func addPencilLineToPath(path: UIBezierPath, startPoint: CGVector, endPoint: CGVector, material: SketchMaterial)
	{
		var lineVector = endPoint - startPoint
		var lineDir = lineVector.normal
		var lineLength = lineVector.length
		
		var p0 = startPoint
		while(true)
		{
			var p1 = p0 + lineDir * material.lineDensity
			
			path.moveToPoint(p0.randomOffset(material.pixJitterDistance).toCGPoint())
			path.addLineToPoint(p1.randomOffset(material.pixJitterDistance).toCGPoint())
			
			p0 = p1
			
			// Check our length
			if (p1 - startPoint).length >= lineLength
			{
				break
			}
		}
	}
}
