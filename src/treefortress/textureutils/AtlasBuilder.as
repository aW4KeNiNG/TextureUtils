package treefortress.textureutils
{
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.Dictionary;
    import flash.utils.getTimer;

    import starling.textures.Texture;
    import starling.textures.TextureAtlas;

    import treefortress.utils.StringUtils;

    /*
     Author: Shawn Skinner (treefortress)

     Author: Ossi Rönnberg
     - Extrude parameter

     Author: Pablo Martin
     - Now AtlasBuilder is a instance class, no static.
     - Added constructor parameters maxWidth and maxHeight
     - Split build into 2 methods: buildBitmapData and buildTextureAtlas
     - Added powerOfTwo, square and imagePath parameters in build Methods.
     - Add reset and dispose methods
     - Add appendBitmap method. You can use to build one by one the atlas to know if the bitmap is inserted.
     - Improvement: If extrude = 0, this step is skipped.
     - Improvement: If the bitmap can't be inserted, then it will avoid the extrusion.
     - Improvement: extrude method uses copyPixels for speed.
     - Fix: !rect check in wrong place.
     - Fix: extrude didn't work with extrude > 1.
     - Fix: extrusion frameX and frameY would be negative values.
     - It will have always the minimum texture size.
     - Added static method createMultipleAtlas. It will create multiple textures with single bitmap list if the limit is reached.
     */

    public class AtlasBuilder
	{
        static public const ALLOC_MAXIMUM_SIZE:int = 0;
        static public const ALLOC_DOUBLE_SIZE:int = 1;
        static public const ALLOC_MINIMUM_SIZE:int = 2;

        static public function createMultiplesAtlas(bitmapList:Vector.<Bitmap>, maxWidth:int=2048, maxHeight:int=2048, transparent:Boolean=true,
                                                    powerOfTwo:Boolean=true, square:Boolean=false, allocPolicy:int=ALLOC_DOUBLE_SIZE,
                                                    scale:Number=1, padding:int=2, extrusion:int=0, stopIfLimitExceeded:Boolean=false,
                                                    imagePath:String="atlas%03d.png"):Vector.<AtlasBuilder>
        {
            var builders:Vector.<AtlasBuilder> = new <AtlasBuilder>[];
            var numberRE:RegExp = /%(?P<number>\d+)d/;
            var result:* = numberRE.exec(imagePath);
            var digitsCount:int = (result) ? int(result.number) : 0;
            var count:int = 0;
            while(true)
            {
                if(!bitmapList || bitmapList.length == 0)
                    break;

                var builder:AtlasBuilder = new AtlasBuilder(maxWidth, maxHeight, transparent, powerOfTwo, square, allocPolicy);
                builder.imagePath = imagePath.replace(numberRE, StringUtils.getNumberFormatted(count, digitsCount));
                bitmapList = builder.appendMultiple(bitmapList, scale, padding, extrusion, stopIfLimitExceeded);
                builders.push(builder);
                count++;
            }

            return builders;
        }

		public var packTime:int;
		public var atlasBitmap:BitmapData;

        private var _imagePath:String = "atlas.png";
        public function get imagePath():String { return _imagePath }
        public function set imagePath(value:String):void
        {
            if(_imagePath == value)
                return;

            _imagePath = value;
            _atlasXml = null;
        }

        private var _atlasXml:XML;
        public function get atlasXml():XML
        {
            if(!_atlasXml)
            {
                var subTextures:Array = [];
                for each(var text:String in subTextureMap)
                {
                    subTextures.push(text);
                }
                _atlasXml = new XML('<TextureAtlas imagePath="' + imagePath + '">' + subTextures.join("\n") + "</TextureAtlas>");
            }
            return _atlasXml;
        }

        private var _maxWidth:int;
        public function get maxWidth():int { return _maxWidth }

        private var _maxHeight:int;
        public function get maxHeight():int { return _maxHeight }

        private var _powerOfTwo:Boolean;
        public function get powerOfTwo():Boolean { return _powerOfTwo }

        private var _square:Boolean;
        public function get square():Boolean { return _square }

        private var _transparent:Boolean;
        public function get transparent():Boolean { return _transparent }

        private var _subTextureCount:int;
        public function get subTextureCount():int { return _subTextureCount }

        public var allocPolicy:int;

		private var subTextureMap:Dictionary = new Dictionary();
        private var packer:MaxRectPacker;

		public function AtlasBuilder(maxWidth:int = 2048, maxHeight:int = 2048, transparent:Boolean=true, powerOfTwo:Boolean=true, square:Boolean=false, allocPolicy:int = ALLOC_DOUBLE_SIZE)
		{
            _maxWidth = maxWidth;
            _maxHeight = maxHeight;
            _transparent = transparent;
            _powerOfTwo = powerOfTwo;
            _square = square;
            this.allocPolicy = allocPolicy;

            packer = new MaxRectPacker(maxWidth, maxHeight);
        }

        public function reset():void
        {
            packTime = 0;
            subTextureMap = new Dictionary();
            _atlasXml = null;

            dispose();
        }

        public function dispose():void
        {
            if(atlasBitmap)
            {
                atlasBitmap.dispose();  //TODO - ojo si starling lo mantiene en memoria
                atlasBitmap = null;
            }
        }

        public function contains(name:String):Boolean
        {
            return name in subTextureMap;
        }

        public function getTextureNames():Vector.<String>
        {
            var names:Vector.<String> = new <String>[];
            for(var k:String in subTextureMap)
            {
                names.push(k);
            }

            return names;
        }

        public function adjustTextureForMinimumSize():void
        {
            var oldPolicy:int = allocPolicy;
            allocPolicy = ALLOC_MINIMUM_SIZE;
            reallocAtlasBitmap();
            allocPolicy = oldPolicy;
        }

        /**
         * Insert a bitmap in the atlas.
         * @return True if the bitmap is inserted.
         */
        public function append(bitmap:Bitmap, scale:Number = 1, padding:int = 2, extrusion:int = 0):Boolean
        {
            var rect:Rectangle = packBitmap(bitmap, scale, padding, extrusion);
            if(!rect)
                return false;

            if(extrusion > 0)
                bitmap = extrude(bitmap, extrusion, transparent);

            //Check Atlas size
            if(!atlasBitmap
                    || rect.x + rect.width > atlasBitmap.width
                    || rect.y + rect.height > atlasBitmap.height)
            {
                reallocAtlasBitmap(rect.x + rect.width, rect.y + rect.height);
            }

            //Apply scale
            var matrix:Matrix = new Matrix(scale, 0, 0, scale, rect.x, rect.y);
            atlasBitmap.draw(bitmap, matrix, null, null, null, true);

            _atlasXml = null;
            return true;
        }
		
		public function appendMultiple(bitmapList:Vector.<Bitmap>, scale:Number = 1, padding:int = 2, extrusion:int = 0, stopIfLimitExceeded:Boolean=false):Vector.<Bitmap>
		{
			var t:int = getTimer();

            var bitmapsNotIncluded:Vector.<Bitmap>;
			var rectangles:Vector.<Rectangle> = new Vector.<Rectangle>();
			for(var i:int = 0; i < bitmapList.length; i++)
			{
                var bitmap:Bitmap = bitmapList[i];

                var rect:Rectangle = packBitmap(bitmap, scale, padding, extrusion);
                if (!rect)
                {
                    trace("Texture Limit Exceeded");
                    if(stopIfLimitExceeded)
                    {
                        bitmapsNotIncluded = bitmapList.slice(i);
                        break;
                    }
                    else
                    {
                        if(!bitmapsNotIncluded)
                            bitmapsNotIncluded = new <Bitmap>[];
                        bitmapsNotIncluded.push(bitmap);
                    }
                }

                rectangles.push(rect);
            }

            var bounds:Rectangle = packer.getBounds();
            if(!atlasBitmap
               || bounds.width > atlasBitmap.width
               || bounds.height > atlasBitmap.height)
                reallocAtlasBitmap(bounds.width, bounds.height);

            //Draw when all process is finished, avoid unnecesary realloc
            var m:Matrix = new Matrix();
            for(i = 0; i < rectangles.length; i++)
            {
                rect = rectangles[i];
                if(!rect)
                    continue;

                bitmap = bitmapList[i];
                if(extrusion > 0)
                    bitmap = extrude(bitmap, extrusion, transparent);

                //Apply scale & translation
                m.setTo(scale, 0, 0, scale, rect.x, rect.y);
                atlasBitmap.draw(bitmap, m, null, null, null, true);

                if(bitmapList[i] != bitmap)
                    bitmap.bitmapData.dispose();    //Created by extrude method
            }

			//Save elapsed time in case we're curious how long this took
			packTime = getTimer() - t;

            _atlasXml = null;
			return bitmapsNotIncluded;
		}

        public function buildTextureAtlas(bitmapList:Vector.<Bitmap>, scale:Number = 1, padding:int = 2, extrusion:int = 0):TextureAtlas
        {
            appendMultiple(bitmapList, scale, padding, extrusion);

            //Create the atlas
            var texture:Texture = Texture.fromBitmapData(atlasBitmap, false);
            var atlas:TextureAtlas = new TextureAtlas(texture, atlasXml);

            return atlas;
        }

        private function packBitmap(bitmap:Bitmap, scale:Number = 1, padding:int = 2, extrusion:int = 0):Rectangle
        {
            var rect:Rectangle = packer.quickInsert((bitmap.width * scale) + (padding + extrusion) * 2, (bitmap.height * scale) + (padding + extrusion) * 2);
            if (!rect)
            {
                trace("Texture Limit Exceeded");
                return null;
            }

            //Add padding
            rect.x += padding;
            rect.y += padding;
            rect.width -= padding * 2;
            rect.height -= padding * 2;

            //Create XML line item for TextureAtlas
            var subtextureXml:String = '<SubTexture name="'+bitmap.name+'" ' +
                    'x="'+rect.x+'" y="'+rect.y+'" width="'+rect.width+'" height="'+rect.height;
            if(extrusion)
                subtextureXml += '" frameX="'+String(-extrusion)+'" frameY="'+String(-extrusion)+'" ' +
                        'frameWidth="'+(rect.width - extrusion*2)+'" frameHeight="'+(rect.height - extrusion*2);
            subtextureXml += '"/>';

            subTextureMap[bitmap.name] = subtextureXml;
            _subTextureCount++;

            return rect;
        }

        protected function reallocAtlasBitmap(minWidth:int = 0, minHeight:int = 0):Boolean
        {
            if(atlasBitmap && atlasBitmap.width == _maxWidth && atlasBitmap.height == _maxHeight)
            {
                return false;
            }
            else
            {
                switch(allocPolicy)
                {
                    case ALLOC_MAXIMUM_SIZE:
                        var newWidth:int = _maxWidth;
                        var newHeight:int = _maxHeight;
                        break;
                    case ALLOC_DOUBLE_SIZE:
                        if(!atlasBitmap)
                        {
                            newWidth = (minWidth != 0) ? minWidth : 32;
                            newHeight = (minHeight != 0) ? minHeight : 32;
                            if(_powerOfTwo)
                            {
                                if(_square)
                                {
                                    newWidth = newHeight = MaxRectPacker.getPOTSize(Math.max(newWidth, newHeight));
                                }
                                else
                                {
                                    newWidth = MaxRectPacker.getPOTSize(newWidth);
                                    newHeight = MaxRectPacker.getPOTSize(newHeight);
                                }
                            }
                        }
                        else
                        {
                            newWidth = atlasBitmap.width * 2;
                            newHeight = atlasBitmap.height * 2;
                        }
                        break;
                    case ALLOC_MINIMUM_SIZE:
                        var rect:Rectangle = (_powerOfTwo) ? packer.getPOTBounds(_square) : packer.getBounds();
                        newWidth = rect.width;
                        newHeight = rect.height;
                        break;
                }

                if(newWidth > _maxWidth)    newWidth = _maxWidth;
                if(newHeight > _maxHeight)  newHeight = _maxHeight;

                if(!atlasBitmap || newWidth != atlasBitmap.width || newHeight != atlasBitmap.height)
                {
                    var newBmd:BitmapData = new BitmapData(newWidth, newHeight, transparent, 0x00FFFFFF);

                    if(atlasBitmap)
                    {
                        newBmd.copyPixels(atlasBitmap, atlasBitmap.rect, new Point());
                        atlasBitmap.dispose();  //FIXME - Starling puede mantenerlo para el contexto
                    }

                    atlasBitmap = newBmd;
                }
                return true;
            }
        }
		
		private static function extrude(bitmap:Bitmap, extrude:int = 1, transparent:Boolean = true):Bitmap
		{
            if(extrude <= 0)
                return bitmap;

			var newBitmapData:BitmapData = new BitmapData(bitmap.width + (extrude * 2), bitmap.height + (extrude * 2), transparent, 0x00FFFFFF);
			newBitmapData.copyPixels(bitmap.bitmapData, new Rectangle(0, 0, bitmap.width, bitmap.height), new Point(extrude, extrude), null, null, true);

            for(var i:int = 0; i<extrude; i++)
            {
                // Top
                newBitmapData.copyPixels(newBitmapData, new Rectangle(extrude, extrude, newBitmapData.width - (extrude*2), 1), new Point(extrude, i));

                //Bottom
                newBitmapData.copyPixels(newBitmapData, new Rectangle(extrude, newBitmapData.height - extrude - 1, newBitmapData.width - (extrude*2), 1), new Point(extrude, newBitmapData.height - i - 1));

                //Left
                newBitmapData.copyPixels(newBitmapData, new Rectangle(extrude, extrude, 1, newBitmapData.height - (extrude*2)), new Point(i, extrude));

                //Right
                newBitmapData.copyPixels(newBitmapData, new Rectangle(newBitmapData.width - extrude - 1, extrude, 1, newBitmapData.height - (extrude*2)), new Point(newBitmapData.width - i - 1, extrude));
            }
			
			var newBitmap:Bitmap = new Bitmap(newBitmapData);
			newBitmap.name = bitmap.name;
			
			return newBitmap;
		}
	}
}
