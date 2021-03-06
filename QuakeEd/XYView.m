#import "qedefs.h"

XYView *xyview_i;

id	scalemenu_i, gridmenu_i, scrollview_i, gridbutton_i, scalebutton_i;

vec3_t		xy_viewnormal;		// v_forward for xy view
float		xy_viewdist;		// clip behind this plane

@implementation XYView

/*
 ==================
 embedInScrollView:
 ==================
 */
- (PopScrollView*)embedInScrollView
{
	///**************************************************************[self allocateGState];
	
	realbounds = NSMakeRect(0,0,0,0);
	
	gridsize = 16;
	scale = 1.0;
	xyview_i = self;
	
	xy_viewnormal[2] = -1;
	xy_viewdist = -1024;
	
//		
// initialize the pop up menus
//
    scalebutton_i = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	scalemenu_i = [scalebutton_i menu];
	[scalebutton_i setTarget: self];
	[scalebutton_i setAction: @selector(scaleMenuTarget:)];

    [scalemenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"12.5%" action:nil keyEquivalent:@""]];
	[scalemenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"25%" action:nil keyEquivalent:@""]];
	[scalemenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"50%" action:nil keyEquivalent:@""]];
	[scalemenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"75%" action:nil keyEquivalent:@""]];
	[scalemenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"100%" action:nil keyEquivalent:@""]];
	[scalemenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"200%" action:nil keyEquivalent:@""]];
	[scalemenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"300%" action:nil keyEquivalent:@""]];
    [scalebutton_i selectItem:[[scalemenu_i itemArray] objectAtIndex:4]];


    gridbutton_i = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    gridmenu_i = [gridbutton_i menu];
	[gridbutton_i setTarget: self];
	[gridbutton_i setAction: @selector(gridMenuTarget:)];

	[gridmenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"grid 1" action:nil keyEquivalent:@""]];
	[gridmenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"grid 2" action:nil keyEquivalent:@""]];
	[gridmenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"grid 4" action:nil keyEquivalent:@""]];
	[gridmenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"grid 8" action:nil keyEquivalent:@""]];
	[gridmenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"grid 16" action:nil keyEquivalent:@""]];
	[gridmenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"grid 32" action:nil keyEquivalent:@""]];
	[gridmenu_i addItem: [[NSMenuItem alloc] initWithTitle:@"grid 64" action:nil keyEquivalent:@""]];
	
    [gridbutton_i selectItem:[[gridmenu_i itemArray] objectAtIndex:4]];
	
// initialize the scroll view
	scrollview_i = [[PopScrollView alloc] 
		initWithFrame: 		self.frame
		button1: 		scalebutton_i
		button2:		gridbutton_i
	];
    [scrollview_i setCopiesOnScroll:NO];
    [scrollview_i setHorizontalScrollElasticity:NSScrollElasticityNone];
    [scrollview_i setVerticalScrollElasticity:NSScrollElasticityNone];
	[scrollview_i setLineScroll: 64];
	///**************************************************************[scrollview_i setAutosizing: NX_WIDTHSIZABLE | NX_HEIGHTSIZABLE];
	
// link objects together
	[scrollview_i setDocumentView: self];
	
	return scrollview_i;

}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- setModeRadio: m
{ // this should be set from IB, but because I toss myself in a popscrollview
// the connection gets lost
	mode_radio_i = m;
	[mode_radio_i setTarget: self];
	[mode_radio_i setAction: @selector(drawMode:)];
	return self;
}

- drawMode: sender
{
	///**************************************************************drawmode = [sender selectedCol];
	[quakeed_i updateXY];
	return self;
}

- setDrawMode: (drawmode_t)mode
{
	drawmode = mode;
	///**************************************************************[mode_radio_i selectCellAt:0: mode];
	[quakeed_i updateXY];
	return self;
}


- (float)currentScale
{
	return scale;
}

/*
===================
setOrigin:scale:
===================
*/
- setOrigin: (NSPoint *)pt scale: (float)sc
{
	NSRect		sframe;
	NSRect		newbounds;
	
//
// calculate the area visible in the cliprect
//
	scale = sc;
	
    sframe = self.superview.frame;
	newbounds = self.superview.frame;
	newbounds.origin = *pt;
	newbounds.size.width /= scale; 
	newbounds.size.height /= scale; 
	
//
// union with the realbounds
//
	newbounds = NSUnionRect (realbounds, newbounds);

//
// size this view
//
    [self setFrameSize:newbounds.size];
    [self setBoundsOrigin:newbounds.origin];
    [self setFrameOrigin:newbounds.origin];
	
//
// scroll and scale the clip view
//
    [self.superview setBoundsSize:NSMakeSize(
		  sframe.size.width/scale
		, sframe.size.height/scale)];
    [self.superview setBoundsOrigin:NSMakePoint(pt->x, pt->y)];

	[scrollview_i display];
	
	return self;
}

- centerOn: (vec3_t)org
{
	NSRect	sbounds;
	NSPoint	mid, delta;
	
	sbounds = [[xyview_i superview] bounds];
	
	mid.x = sbounds.origin.x + sbounds.size.width/2;
	mid.y = sbounds.origin.y + sbounds.size.height/2;
	
	delta.x = org[0] - mid.x;
	delta.y = org[1] - mid.y;

	sbounds.origin.x += delta.x;
	sbounds.origin.y += delta.y;
	
	[self setOrigin: &sbounds.origin scale: scale];
	return self;
}

/*
==================
newSuperBounds

When superview is resized
==================
*/
- newSuperBounds
{
	NSRect	r;
	
    r = self.superview.bounds;
	[self newRealBounds: &r];
	
	return self;
}

/*
===================
newRealBounds

Called when the realbounds rectangle is changed.
Should only change the scroll bars, not cause any redraws.
If realbounds has shrunk, nothing will change.
===================
*/
- newRealBounds: (NSRect *)nb
{
	NSRect		sbounds;
	
	realbounds = *nb;
	
//
// calculate the area visible in the cliprect
//
    sbounds = self.superview.bounds;
	sbounds = NSUnionRect (*nb, sbounds);

//
// size this view
//
    self.postsFrameChangedNotifications = NO;
    [self setFrameSize:sbounds.size];
    [self setBoundsOrigin:sbounds.origin];
	[self setFrameOrigin:sbounds.origin];
	self.postsFrameChangedNotifications = YES;

	[scrollview_i reflectScrolledClipView: (NSClipView*)self.superview];
	
	[[scrollview_i horizontalScroller] display];
	[[scrollview_i verticalScroller] display];
	
	return self;
}


/*
====================
scaleMenuTarget:

Called when the scaler popup on the window is used
====================
*/

- scaleMenuTarget: sender
{
	NSString	*item;
	NSRect		visrect, sframe;
	float		nscale;
	
	item = [[sender selectedItem] title];
	sscanf ([item cStringUsingEncoding:[NSString defaultCStringEncoding]],"%f",&nscale);
	nscale /= 100;
	
	if (nscale == scale)
		return NULL;
		
// keep the center of the view constant
	visrect = self.superview.bounds;
	sframe = self.superview.frame;
	visrect.origin.x += visrect.size.width/2;
	visrect.origin.y += visrect.size.height/2;
	
	visrect.origin.x -= sframe.size.width/2/nscale;
	visrect.origin.y -= sframe.size.height/2/nscale;
	
	[self setOrigin: &visrect.origin scale: nscale];
	
	return self;
}

/*
==============
zoomIn
==============
*/
- zoomIn: (NSPoint *)constant
{
///**************************************************************	id			itemlist;
/*	int			selected, numrows, numcollumns;

	NSRect		visrect;
	NSPoint		ofs, new;

//
// set the popup
//
	itemlist = [scalemenu_i itemList];
	[itemlist getNumRows: &numrows numCols:&numcollumns];
	
	selected = [itemlist selectedRow] + 1;
	if (selected >= numrows)
		return NULL;
		
	[itemlist selectCellAt: selected : 0];
	[scalebutton_i setTitle: [[itemlist selectedCell] title]];

//
// zoom the view
//
	[superview getBounds: &visrect];
	ofs.x = constant->x - visrect.origin.x;
	ofs.y = constant->y - visrect.origin.y;
	
	new.x = constant->x - ofs.x / 2;
	new.y = constant->y - ofs.y / 2;

	[self setOrigin: &new scale: scale*2];*/
	
	return self;
}


/*
==============
zoomOut
==============
*/
- zoomOut: (NSPoint *)constant
{
///**************************************************************	id			itemlist;
/*	int			selected, numrows, numcollumns;

	NSRect		visrect;
	NSPoint		ofs, new;
	
//
// set the popup
//
	itemlist = [scalemenu_i itemList];
	[itemlist getNumRows: &numrows numCols:&numcollumns];
	
	selected = [itemlist selectedRow] - 1;
	if (selected < 0)
		return NULL;
		
	[itemlist selectCellAt: selected : 0];
	[scalebutton_i setTitle: [[itemlist selectedCell] title]];

//
// zoom the view
//
	[superview getBounds: &visrect];
	ofs.x = constant->x - visrect.origin.x;
	ofs.y = constant->y - visrect.origin.y;
	
	new.x = constant->x - ofs.x * 2;
	new.y = constant->y - ofs.y * 2;

	[self setOrigin: &new scale: scale/2];*/
	
	return self;
}


/*
====================
gridMenuTarget:

Called when the scaler popup on the window is used
====================
*/

- gridMenuTarget: sender
{
	NSString	*item;
	int			grid;
	
	item = [[sender selectedItem] title];
    sscanf ([item cStringUsingEncoding:[NSString defaultCStringEncoding]],"grid %d",&grid);

	if (grid == gridsize)
		return NULL;
		
	gridsize = grid;
	[quakeed_i updateAll];

	return self;
}


/*
====================
snapToGrid
====================
*/
- (float) snapToGrid: (float)f
{
	int		i;
	
	i = rint(f/gridsize);
	
	return i*gridsize;
}

- (int)gridsize
{
	return gridsize;
}



/*
===================
addToScrollRange::
===================
*/
- addToScrollRange: (float)x :(float)y;
{
	if (x < newrect.origin.x)
	{
		newrect.size.width += newrect.origin.x - x;
		newrect.origin.x = x;
	}
	
	if (y < newrect.origin.y)
	{
		newrect.size.height += newrect.origin.y - y;
		newrect.origin.y = y;
	}
	
	if (x > newrect.origin.x + newrect.size.width)
		newrect.size.width += x - (newrect.origin.x+newrect.size.width);
		
	if (y > newrect.origin.y + newrect.size.height)
		newrect.size.height += y - (newrect.origin.y+newrect.size.height);
		
	return self;
}

/*
===================
superviewChanged
===================
*/
- superviewChanged
{	
	[self newRealBounds: &realbounds];
	
	return self;
}


/*
===============================================================================

						DRAWING METHODS

===============================================================================
*/

vec3_t	cur_linecolor;

void linestart (float r, float g, float b)
{
    CGPathRelease(upath);
    upath = CGPathCreateMutable();
	cur_linecolor[0] = r;
	cur_linecolor[1] = g;
	cur_linecolor[2] = b;
}

void lineflush (void)
{
    if (CGPathIsEmpty(upath))
		return;
    CGContextRef context = [NSGraphicsContext currentContext].CGContext;
    CGPathCloseSubpath(upath);
    CGContextSetStrokeColorWithColor(context, [NSColor colorWithRed:cur_linecolor[0] green:cur_linecolor[1] blue:cur_linecolor[2] alpha:1.0].CGColor);
    CGContextAddPath(context, upath);
    CGContextStrokePath(context);
    CGPathRelease(upath);
    upath = CGPathCreateMutable();
}

void linecolor (float r, float g, float b)
{
	if (cur_linecolor[0] == r && cur_linecolor[1] == g && cur_linecolor[2] == b)
		return;	// do nothing
	lineflush ();
	cur_linecolor[0] = r;
	cur_linecolor[1] = g;
	cur_linecolor[2] = b;
}

void XYmoveto (vec3_t pt)
{
	CGPathMoveToPoint (upath, nil, pt[0], pt[1]);
}

void XYlineto (vec3_t pt)
{
	CGPathAddLineToPoint (upath, nil, pt[0], pt[1]);
}

/*
============
drawGrid

Draws tile markings every 64 units, and grid markings at the grid scale if
the grid lines are greater than or equal to 4 pixels apart

Rect is in global world (unscaled) coordinates
============
*/

- drawGrid: (NSRect)rect
{
	int	x,y, stopx, stopy;
	float	top,bottom,right,left;
	NSString*	text;
	BOOL	showcoords;
	
	showcoords = [quakeed_i showCoordinates];

	left = rect.origin.x-1;
	bottom = rect.origin.y-1;
	right = rect.origin.x+rect.size.width+2;
	top = rect.origin.y+rect.size.height+2;

    
    CGContextRef context = [NSGraphicsContext currentContext].CGContext;
	CGContextSetLineWidth (context, 0.15);

//
// grid
//
// can't just divide by grid size because of negetive coordinate
// truncating direction
//
	if (gridsize >= 4/scale)
	{
		y = floor(bottom/gridsize);
		stopy = floor(top/gridsize);
		x = floor(left/gridsize);
		stopx = floor(right/gridsize);
		
		y *= gridsize;
		stopy *= gridsize;
		x *= gridsize;
		stopx *= gridsize;
		if (y<bottom)
			y+= gridsize;
		if (x<left)
			x+= gridsize;
		if (stopx >= right)
			stopx -= gridsize;
		if (stopy >= top)
			stopy -= gridsize;
			
        CGPathRelease(upath);
        upath = CGPathCreateMutable();
		
		for ( ; y<=stopy ; y+= gridsize)
			if (y&63)
			{
				CGPathMoveToPoint (upath, nil, left, y);
				CGPathAddLineToPoint (upath, nil, right, y);
			}
	
		for ( ; x<=stopx ; x+= gridsize)
			if (x&63)
			{
				CGPathMoveToPoint (upath, nil, x, top);
				CGPathAddLineToPoint (upath, nil, x, bottom);
			}
		CGPathCloseSubpath (upath);
CGContextSetStrokeColorWithColor(context, [NSColor colorWithRed:0.8 green:0.8 blue:1.0 alpha:1.0].CGColor);	// thin grid color
        CGContextAddPath(context, upath);
        CGContextStrokePath(context);
	
	}

//
// tiles
//
	CGContextSetGrayStrokeColor(context, 0, 1.0);		// for text

	if (scale > 4.0/64)
	{
		y = floor(bottom/64);
		stopy = floor(top/64);
		x = floor(left/64);
		stopx = floor(right/64);
		
		y *= 64;
		stopy *= 64;
		x *= 64;
		stopx *= 64;
		if (y<bottom)
			y+= 64;
		if (x<left)
			x+= 64;
		if (stopx >= right)
			stopx -= 64;
		if (stopy >= top)
			stopy -= 64;
			
        CGPathRelease(upath);
        upath = CGPathCreateMutable();
		
		for ( ; y<=stopy ; y+= 64)
		{
			if (showcoords)
			{
                text = [NSString stringWithFormat:@"%i", y];
                [text drawAtPoint:CGPointMake(left,y) withAttributes:nil];
			}
            CGPathMoveToPoint (upath, nil, left, y);
            CGPathAddLineToPoint (upath, nil, right, y);
		}
	
		for ( ; x<=stopx ; x+= 64)
		{
			if (showcoords)
			{
                text = [NSString stringWithFormat:@"%i", x];
                [text drawAtPoint:CGPointMake(x,bottom+2) withAttributes:nil];
			}
            CGPathMoveToPoint (upath, nil, x, top);
            CGPathAddLineToPoint (upath, nil, x, bottom);
		}
	
        CGPathCloseSubpath (upath);
        CGContextSetGrayStrokeColor(context, 12.0/16, 1.0);
        CGContextAddPath(context, upath);
        CGContextStrokePath(context);
	}

	return self;
}

/*
==================
drawWire
==================
*/
- drawWire:(NSRect)dirtyRect
{
	NSRect	visRect;
	int	i,j, c, c2;
	id	ent, brush;
	vec3_t	mins, maxs;
	BOOL	drawnames;

	drawnames = [quakeed_i showNames];
	
	if ([quakeed_i showCoordinates])	// if coords are showing, update everything
	{
        visRect = self.visibleRect;
        dirtyRect = visRect;
        xy_draw_rect = dirtyRect;
	}

	
    CGContextRef context = [NSGraphicsContext currentContext].CGContext;
	NSRectClip(dirtyRect);
		
// erase window
	NSEraseRect (dirtyRect);
	
// draw grid
	[self drawGrid: dirtyRect];

// draw all entities, world first so entities take priority
	linestart (0,0,0);

	c = [map_i count];
	for (i=0 ; i<c ; i++)
	{
		ent = [map_i objectAtIndex: i];
		c2 = [ent count];
		for (j = c2-1 ; j >=0 ; j--)
		{
			brush = [ent objectAtIndex: j];
			if ( [brush selected] )
				continue;
			if ([brush regioned])
				continue;
			[brush XYDrawSelf];
		}
		if (i > 0 && drawnames)
		{	// draw entity names
			brush = [ent objectAtIndex: 0];
			if (![brush regioned])
			{
				[brush getMins: mins maxs: maxs];
                CGContextSetStrokeColorWithColor(context, [NSColor colorWithRed:0 green:0 blue:0 alpha:1.0].CGColor);
                NSString *text = [NSString stringWithCString:[ent valueForQKey: "classname"] encoding:[NSString defaultCStringEncoding]];
                [text drawAtPoint:CGPointMake(mins[0], mins[1]) withAttributes:nil];
			}
		}
	}

	lineflush ();
	
// resize if needed
	newrect.origin.x -= gridsize;
	newrect.origin.y -= gridsize;
	newrect.size.width += 2*gridsize;
	newrect.size.height += 2*gridsize;
	if (!NSEqualRects (newrect, realbounds))
		[self newRealBounds: &newrect];

	return self;
}


/*
=============
drawSolid
=============
*/
- drawSolid
{
	unsigned char	*planes[5];
	NSRect	visRect;

    visRect = self.visibleRect;

//
// draw the image into imagebuffer
//
	r_origin[0] = visRect.origin.x;
	r_origin[1] = visRect.origin.y;
	
	r_origin[2] = scale/2;	// using Z as a scale for the 2D projection
	
	r_width = visRect.size.width*r_origin[2];
	r_height = visRect.size.height*r_origin[2];
	
	if (r_width != xywidth || r_height != xyheight)
	{
		xywidth = r_width;
		xyheight = r_height;

		if (xypicbuffer)
		{
			free (xypicbuffer);
			free (xyzbuffer);
		}
		xypicbuffer = malloc (r_width*(r_height+1)*4);
		xyzbuffer = malloc (r_width*(r_height+1)*4);
	}
	
	r_picbuffer = xypicbuffer;
	r_zbuffer = xyzbuffer;
	
	REN_BeginXY ();
	REN_ClearBuffers ();

//
// render the entities
//
	[map_i makeAllPerform: @selector(XYRenderSelf)];

//
// display the output
//
	[self lockFocus];
	[[self window] setBackingType:NSBackingStoreRetained];

	planes[0] = (unsigned char *)r_picbuffer;
	NSDrawBitmap(
		visRect,
		r_width, 
		r_height,
		8,
		3,
		32,
		r_width*4,
		NO,
		NO,
		NSDeviceRGBColorSpace,
		planes
	);
	
	///**************************************************************NXPing ();
	[[self window] setBackingType:NSBackingStoreBuffered];
	[self unlockFocus];
	
	return self;
}

/*
===================
drawRect
===================
*/
NSRect	xy_draw_rect;
- (void)drawRect:(NSRect)dirtyRect
{
	static float	drawtime;	// static to shut up compiler warning

	if (timedrawing)
		drawtime = I_FloatTime ();

	xy_draw_rect = dirtyRect;
	newrect.origin.x = newrect.origin.y = 99999;
	newrect.size.width = newrect.size.height = -2*99999;

// setup for text
    CGContextRef context = [NSGraphicsContext currentContext].CGContext;
    CGContextSetFont(context, (CGFontRef)[NSFont fontWithName:@"Helvetica-Medium" size:10/scale]);

	if (drawmode == dr_texture || drawmode == dr_flat)
		[self drawSolid];
	else
		[self drawWire: dirtyRect];
	
	if (timedrawing)
	{
		///**************************************************************NXPing ();
		drawtime = I_FloatTime() - drawtime;
		printf ("CameraView drawtime: %5.3f\n", drawtime);
	}

    linestart (0,0,0);
    [map_i makeSelectedPerform: @selector(XYDrawSelf)];
    lineflush ();
    [cameraview_i XYDrawSelf];
    [zview_i XYDrawSelf];
    ///**************************************************************[clipper_i XYDrawSelf];
}



/*
===============================================================================

						USER INTERACTION

===============================================================================
*/

/*
================
dragLoop:
================
*/
static	NSPoint		oldreletive;
- dragFrom: (NSEvent *)startevent 
	useGrid: (BOOL)ug
	callback: (void (*) (float dx, float dy)) callback
{
	NSEvent		*event;
	NSPoint		startpt, newpt;
	NSPoint		reletive, delta;

	startpt = startevent.locationInWindow;
	startpt = [self convertPoint:startpt  fromView:NULL];
	
	oldreletive.x = oldreletive.y = 0;
	
	if (ug)
	{
		startpt.x = [self snapToGrid: startpt.x];
		startpt.y = [self snapToGrid: startpt.y];
	}

    while (1)
	{
		event = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask
			| NSRightMouseUpMask | NSRightMouseDraggedMask | NSApplicationDefined untilDate:nil inMode:NSEventTrackingRunLoopMode dequeue:YES];
        if (event == nil)
            continue;

		if (event.type == NSLeftMouseUp || event.type == NSRightMouseUp)
			break;
		if (event.type == NSApplicationDefined)
		{	// doesn't work.  grrr.
			///**************************************************************[quakeed_i applicationDefined:event];
			continue;
		}
		
		newpt = event.locationInWindow;
		newpt = [self convertPoint:newpt  fromView:NULL];

		if (ug)
		{
			newpt.x = [self snapToGrid: newpt.x];
			newpt.y = [self snapToGrid: newpt.y];
		}

		reletive.x = newpt.x - startpt.x;
		reletive.y = newpt.y - startpt.y;
		if (reletive.x == oldreletive.x && reletive.y == oldreletive.y)
			continue;

		delta.x = reletive.x - oldreletive.x;
		delta.y = reletive.y - oldreletive.y;
		oldreletive = reletive;			

		callback (delta.x , delta.y );
		
	}

	return self;
}

//============================================================================


void DragCallback (float dx, float dy)
{
	sb_translate[0] = dx;
	sb_translate[1] = dy;
	sb_translate[2] = 0;

	[map_i makeSelectedPerform: @selector(translate)];
	
	[quakeed_i redrawInstance];
}

- selectionDragFrom: (NSEvent*)theEvent	
{
	qprintf ("dragging selection");
	[self	dragFrom:	theEvent 
			useGrid:	YES
			callback:	DragCallback ];
	[quakeed_i updateAll];
	qprintf ("");
	return self;
	
}

//============================================================================

void ScrollCallback (float dx, float dy)
{
	NSRect		basebounds;
	NSPoint		neworg;
	float		scale;
	
    basebounds = [ [xyview_i superview] bounds];
    basebounds = [xyview_i convertRect:basebounds fromView:[xyview_i superview]];

	neworg.x = basebounds.origin.x - dx;
	neworg.y = basebounds.origin.y - dy;
	
	scale = [xyview_i currentScale];
	
	oldreletive.x -= dx;
	oldreletive.y -= dy;
	[xyview_i setOrigin: &neworg scale: scale];
}

- scrollDragFrom: (NSEvent*)theEvent	
{
	qprintf ("scrolling view");
	[self	dragFrom:	theEvent 
			useGrid:	YES
			callback:	ScrollCallback ];
	qprintf ("");
	return self;
	
}

//============================================================================

vec3_t	direction;

void DirectionCallback (float dx, float dy)
{
	vec3_t	org;
	float	ya;
	
	direction[0] += dx;
	direction[1] += dy;
	
	[cameraview_i getOrigin: org];

	if (direction[0] == org[0] && direction[1] == org[1])
		return;
		
	ya = atan2 (direction[1] - org[1], direction[0] - org[0]);

	[cameraview_i setOrigin: org angle: ya];
	[quakeed_i newinstance];
	[cameraview_i display];
}

- directionDragFrom: (NSEvent*)theEvent	
{
	NSPoint			pt;

	qprintf ("changing camera direction");

	pt= theEvent.locationInWindow;
	pt = [self convertPoint:pt  fromView:NULL];

	direction[0] = pt.x;
	direction[1] = pt.y;
	
	DirectionCallback (0,0);
	
	[self	dragFrom:	theEvent 
			useGrid:	NO
			callback:	DirectionCallback ];
	qprintf ("");
	return self;	
}

//============================================================================

id	newbrush;
vec3_t	neworg, newdrag;

void NewCallback (float dx, float dy)
{
	vec3_t	min, max;
	int		i;
	
	newdrag[0] += dx;
	newdrag[1] += dy;
	
	for (i=0 ; i<3 ; i++)
	{
		if (neworg[i] < newdrag[i])
		{
			min[i] = neworg[i];
			max[i] = newdrag[i];
		}
		else
		{
			min[i] = newdrag[i];
			max[i] = neworg[i];
		}
	}
	
	[newbrush  setMins: min maxs: max];
	
	[quakeed_i redrawInstance];
}

- newBrushDragFrom: (NSEvent*)theEvent	
{
	id				owner;
	texturedef_t	td;
	NSPoint			pt;

	qprintf ("sizing new brush");
	
	pt= theEvent.locationInWindow;
	pt = [self convertPoint:pt  fromView:NULL];

	neworg[0] = [self snapToGrid: pt.x];
	neworg[1] = [self snapToGrid: pt.y];
	neworg[2] = [map_i currentMinZ];

	newdrag[0] = neworg[0];
	newdrag[1] = neworg[1];
	newdrag[2] = [map_i currentMaxZ];
	
	owner = [map_i currentEntity];
	
	[texturepalette_i getTextureDef: &td];
	
	newbrush = [[SetBrush alloc] initOwner: owner
		mins: neworg maxs: newdrag texture: &td];
	[owner addObject: newbrush];
	
	///**************************************************************[newbrush setSelected: YES];
	
	[self	dragFrom:	theEvent 
			useGrid:	YES
			callback:	NewCallback ];
			
	[newbrush removeIfInvalid];
	
	[quakeed_i updateCamera];
	qprintf ("");
	return self;
	
}

//============================================================================

void ControlCallback (float dx, float dy)
{
	int		i;
	
	for (i=0 ; i<numcontrolpoints ; i++)
	{
		controlpoints[i][0] += dx;
		controlpoints[i][1] += dy;
	}
	
	[[map_i selectedBrush] calcWindings];	
	[quakeed_i redrawInstance];
}

- (BOOL)planeDragFrom: (NSEvent*)theEvent	
{
	NSPoint			pt;
	vec3_t			dragpoint;

	if ([map_i numSelected] != 1)
		return NO;
		
	pt= theEvent.locationInWindow;
	pt = [self convertPoint:pt  fromView:NULL];

	dragpoint[0] = pt.x;
	dragpoint[1] = pt.y;
	dragpoint[2] = 2048;
		
	[[map_i selectedBrush] getXYdragface: dragpoint];
	if (!numcontrolpoints)
		return NO;
	
	qprintf ("dragging brush plane");
	
	pt= theEvent.locationInWindow;
	pt = [self convertPoint:pt  fromView:NULL];

	[self	dragFrom:	theEvent 
			useGrid:	YES
			callback:	ControlCallback ];
			
	[[map_i selectedBrush] removeIfInvalid];
	
	[quakeed_i updateAll];

	qprintf ("");
	return YES;
}

- (BOOL)shearDragFrom: (NSEvent*)theEvent	
{
	NSPoint			pt;
	vec3_t			dragpoint;
	vec3_t			p1, p2;
	float			time;
	id				br;
	int				face;
	
	if ([map_i numSelected] != 1)
		return NO;
	br = [map_i selectedBrush];
	
	pt= theEvent.locationInWindow;
	pt = [self convertPoint:pt  fromView:NULL];

// if the XY point is inside the brush, make the point on top
	p1[0] = pt.x;
	p1[1] = pt.y;
	VectorCopy (p1, p2);

	p1[2] = -2048*xy_viewnormal[2];
	p2[2] = 2048*xy_viewnormal[2];

	VectorCopy (p1, dragpoint);
	[br hitByRay: p1 : p2 : &time : &face];

	if (time > 0)
	{
		dragpoint[2] = p1[2] + (time-0.01)*xy_viewnormal[2];
	}
	else
	{
		[br getMins: p1 maxs: p2];
		dragpoint[2] = (p1[2] + p2[2])/2;
	}


	[br getXYShearPoints: dragpoint];
	if (!numcontrolpoints)
		return NO;
	
	qprintf ("dragging brush plane");
	
	pt= theEvent.locationInWindow;
	pt = [self convertPoint:pt  fromView:NULL];

	[self	dragFrom:	theEvent 
			useGrid:	YES
			callback:	ControlCallback ];
			
	[br removeIfInvalid];
	
	[quakeed_i updateAll];
	qprintf ("");
	return YES;
}


/*
===============================================================================

						INPUT METHODS

===============================================================================
*/


/*
===================
mouseDown
===================
*/
- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint	pt;
	id		ent;
	vec3_t	p1, p2;
	int		flags;
	
	pt= theEvent.locationInWindow;
	pt = [self convertPoint:pt  fromView:NULL];

	p1[0] = p2[0] = pt.x;
	p1[1] = p2[1] = pt.y;
	p1[2] = xy_viewnormal[2] * -4096;
	p2[2] = xy_viewnormal[2] * 4096;

	flags = theEvent.modifierFlags & (NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask);
	
//
// shift click to select / deselect a brush from the world
//
	if (flags == NSShiftKeyMask)
	{		
		[map_i selectRay: p1 : p2 : YES];
		return;
	}
	
//
// cmd-shift click to set a target/targetname entity connection
//
	if (flags == (NSShiftKeyMask|NSCommandKeyMask) )
	{
		[map_i entityConnect: p1 : p2];
		return;
	}
	
//
// bare click to either drag selection, or rubber band a new brush
//
	if ( flags == 0 )
	{
	// if double click, position Z checker
		if (theEvent.clickCount > 1)
		{
			qprintf ("positioned Z checker");
			[zview_i setPoint: &pt];
			[quakeed_i newinstance];
			[quakeed_i updateZ];
			return;
		}
		
	// check eye
		if ( [cameraview_i XYmouseDown: &pt flags: theEvent.modifierFlags] )
			return;		// camera move
			
	// check z post
		if ( [zview_i XYmouseDown: &pt] )
			return;		// z view move

	// check clippers
		if ( [clipper_i XYDrag: &pt] )
			return;

	// check single plane dragging
		if ( [self planeDragFrom: theEvent] )
			return;

	// check selection
		ent = [map_i grabRay: p1 : p2];
		if (ent)
        {
			[self selectionDragFrom: theEvent];
            return;
        }
		
		if ([map_i numSelected])
		{
			qprintf ("missed");
			return;
		}
		
		[self newBrushDragFrom: theEvent];
	}
	
//
// control click = position and drag camera 
//
	if (flags == NSControlKeyMask)
	{
		[cameraview_i setXYOrigin: &pt];
		[quakeed_i newinstance];
		[cameraview_i display];
		[cameraview_i XYmouseDown: &pt flags: theEvent.modifierFlags];
		qprintf ("");
		return;
	}
		
//
// command click = drag Z checker
//
	if (flags == NSCommandKeyMask)
	{
// check single plane dragging
[self shearDragFrom: theEvent];
return;

		qprintf ("moving Z checker");
		[zview_i setXYOrigin: &pt];
		[quakeed_i updateAll];
		[zview_i XYmouseDown: &pt];
		qprintf ("");
		return;
	}

//
// alt click = set entire brush texture
//
	if (flags == NSAlternateKeyMask)
	{
		if (drawmode != dr_texture)
		{
			qprintf ("No texture setting except in texture mode!\n");
			NopSound ();
			return;
		}
		[map_i setTextureRay: p1 : p2 : YES];
		[quakeed_i updateAll];
		return;
	}
		
//
// ctrl-alt click = set single face texture
//
	if (flags == (NSControlKeyMask | NSAlternateKeyMask) )
	{
		if (drawmode != dr_texture)
		{
			qprintf ("No texture setting except in texture mode!\n");
			NopSound ();
			return;
		}
		[map_i setTextureRay: p1 : p2 : NO];
		[quakeed_i updateAll];
		return;
	}
		
	qprintf ("bad flags for click");
	NopSound ();
}

/*
===================
rightMouseDown
===================
*/
- (void)rightMouseDown:(NSEvent *)theEvent
{
	NSPoint	pt;
	int		flags;
		
	pt= theEvent.locationInWindow;
	pt = [self convertPoint:pt  fromView:NULL];

	flags = theEvent.modifierFlags & (NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask);

	if (flags == NSCommandKeyMask)
	{
		[self scrollDragFrom: theEvent];
        return;
	}

	if (flags == NSAlternateKeyMask)
	{
		[clipper_i XYClick: pt];
        return;
	}
	
	if (flags == 0 || flags == NSControlKeyMask)
	{
		[self directionDragFrom: theEvent];
        return;
	}
	
	qprintf ("bad flags for click");
	NopSound ();
}


@end

