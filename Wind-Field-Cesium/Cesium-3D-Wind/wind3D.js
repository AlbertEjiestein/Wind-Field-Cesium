class Wind3D {
    constructor(panel, mode) {
        var options = {
            baseLayerPicker: false,
            geocoder: false,
            infoBox: false,
            fullscreenElement: 'cesiumContainer',
            scene3DOnly: true
        }

        if (mode.debug) {
            options.useDefaultRenderLoop = false;
        }

        Cesium.Ion.defaultAccessToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiJjY2I0ZjYyNS02MjljLTRiNDYtOGNlMS0wN2YxZmFhMWFmM2QiLCJpZCI6ODY5Miwic2NvcGVzIjpbImFzciIsImdjIl0sImlhdCI6MTU1MjU1MDM5OX0.O90jAY8kMelcVbLqGYzxkfACkA1a0gu-cXsiIVrx5i0';
        this.viewer = new Cesium.Viewer('cesiumContainer', options);
        this.scene = this.viewer.scene;
        this.camera = this.viewer.camera;
        this.ellipsoid = this.scene.globe.ellipsoid;
        this.initHeight = this.ellipsoid.cartesianToCartographic(this.camera.position).height;

        this.panel = panel;

        this.viewerParameters = {
            lonRange: new Cesium.Cartesian2(),
            latRange: new Cesium.Cartesian2(),
            pixelSize: 0.0
        };
        // use a smaller earth radius to make sure distance to camera > 0
        this.globeBoundingSphere = new Cesium.BoundingSphere(Cesium.Cartesian3.ZERO, 0.99 * 6378137.0);
        this.updateViewerParameters();

        DataProcess.loadData().then(
            (data) => {
                this.particleSystem = new ParticleSystem(this.scene.context, data,
                    this.panel.getUserInput(), this.viewerParameters);
                this.addPrimitives();

                this.setupEventListeners();

                if (mode.debug) {
                    this.debug();
                }
            });

        this.imageryLayers = this.viewer.imageryLayers;
        this.setGlobeLayer(this.panel.getUserInput());
    }

    // setViewHeight(){
    //     // 设置鼠标位置经纬度\视角高度实时显示
    //     this.longitude_show=document.getElementById('longitude_show');  
    //     this.latitude_show=document.getElementById('latitude_show');  
    //     this.altitude_show = document.getElementById('altitude_show');
    //     this.canvas = this.scene.canvas;
    //     //具体事件的实现
    //     this.ellipsoid = this.scene.globe.ellipsoid;
    //     this.handler = new Cesium.ScreenSpaceEventHandler(this.canvas);
    //     this.handler.setInputAction(function (movement) {
    //         //捕获椭球体，将笛卡尔二维平面坐标转为椭球体的笛卡尔三维坐标，返回球体表面的点  
    //         var cartesian = viewer.camera.pickEllipsoid(movement.endPosition, this.ellipsoid);
    //         if (cartesian) {
    //             //将笛卡尔三维坐标转为地图坐标（弧度）  
    //             var cartographic = viewer.scene.globe.ellipsoid.cartesianToCartographic(cartesian);
    //             //将地图坐标（弧度）转为十进制的度数  
    //             var lat_String = Cesium.Math.toDegrees(cartographic.latitude).toFixed(2);
    //             var log_String = Cesium.Math.toDegrees(cartographic.longitude).toFixed(2);
    //             // 获取相机的海拔高度作为视角高度/km
    //             this.alti_String = (viewer.camera.positionCartographic.height / 1000).toFixed(2);
    //             this.longitude_show.innerHTML = log_String;
    //             this.latitude_show.innerHTML = lat_String;
    //             this.altitude_show.innerHTML = alti_String;
    //         }
    //     })
    // }

    addPrimitives() {
        // the order of primitives.add() should respect the dependency of primitives
        this.scene.primitives.add(this.particleSystem.particlesComputing.primitives.getWind);
        this.scene.primitives.add(this.particleSystem.particlesComputing.primitives.updateSpeed);
        this.scene.primitives.add(this.particleSystem.particlesComputing.primitives.updatePosition);
        this.scene.primitives.add(this.particleSystem.particlesComputing.primitives.postProcessingPosition);
        this.scene.primitives.add(this.particleSystem.particlesComputing.primitives.postProcessingSpeed);

        this.scene.primitives.add(this.particleSystem.particlesRendering.primitives.segments);
        this.scene.primitives.add(this.particleSystem.particlesRendering.primitives.trails);
        this.scene.primitives.add(this.particleSystem.particlesRendering.primitives.screen);
    }

    updateViewerParameters() {
        var viewRectangle = this.camera.computeViewRectangle(this.scene.globe.ellipsoid);
        var lonLatRange = Util.viewRectangleToLonLatRange(viewRectangle);
        this.viewerParameters.lonRange.x = lonLatRange.lon.min;
        this.viewerParameters.lonRange.y = lonLatRange.lon.max;
        this.viewerParameters.latRange.x = lonLatRange.lat.min;
        this.viewerParameters.latRange.y = lonLatRange.lat.max;

        var pixelSize = this.camera.getPixelSize(
            this.globeBoundingSphere,
            this.scene.drawingBufferWidth,
            this.scene.drawingBufferHeight
        );

        if (pixelSize > 0) {
            this.viewerParameters.pixelSize = pixelSize;
        }
    }

    setGlobeLayer(userInput) {
        this.viewer.imageryLayers.removeAll();
        this.viewer.terrainProvider = new Cesium.EllipsoidTerrainProvider();

        var globeLayer = userInput.globeLayer;
        switch (globeLayer.type) {
            case "NaturalEarthII": {
                this.viewer.imageryLayers.addImageryProvider(
                    Cesium.createTileMapServiceImageryProvider({
                        url: Cesium.buildModuleUrl('Assets/Textures/NaturalEarthII')
                    })
                );
                break;
            }
            case "WMS": {
                this.viewer.imageryLayers.addImageryProvider(new Cesium.WebMapServiceImageryProvider({
                    url: userInput.WMS_URL,
                    layers: globeLayer.layer,
                    parameters: {
                        ColorScaleRange: globeLayer.ColorScaleRange
                    }
                }));
                break;
            }
            case "WorldTerrain": {
                this.viewer.imageryLayers.addImageryProvider(
                    Cesium.createWorldImagery()
                );
                this.viewer.terrainProvider = Cesium.createWorldTerrain();
                break;
            }
        }
    }

    getViewHeight() {
        if (this.viewer) {
            let height = this.ellipsoid.cartesianToCartographic(this.camera.position).height;
            return height;
        }
    }

    getMaxNumByHeight(viewHeight){
        // y=kx+b   k=defaultParticleNum/initHeight
        const k = defaultParticleSystemOptions.maxParticles/this.initHeight;
        if(viewHeight > 20000000){
            return Math.ceil(k * viewHeight + 2000);
        }else if(viewHeight > 15000000){
            return Math.ceil(k * viewHeight + 5000);
        }else if(viewHeight > 10000000){
            return Math.ceil(k * viewHeight + 7000);
        }else if(viewHeight > 5000000){
            return Math.ceil(k * viewHeight + 9000);
        }else if(viewHeight > 1000000){
            return Math.ceil(k * viewHeight + 6000);
        }else if(viewHeight > 100000){
            return Math.ceil(k * viewHeight + 3000);
        }else if(viewHeight > 10000){
            return Math.ceil(k * viewHeight + 1000);
        }else{
            return Math.ceil(k * viewHeight + 200);
        }
    }

    getLineWidthByHeight(viewHeight){
        if(viewHeight > 7000){
            return defaultParticleSystemOptions.lineWidth;
        }else if(viewHeight > 4000){
            return 3.0
        }else if(viewHeight > 1000){
            return 1.5
        }else{
            return 0.5
        }
    }

    getOpacityByHeight(viewHeight){
        if(viewHeight > 60000){
            return defaultParticleSystemOptions.fadeOpacity;
        }else if(viewHeight > 30000){
            return 0.98
        }else if(viewHeight > 15000){
            return 0.96
        }else if(viewHeight > 7000){
            return 0.95
        }else if(viewHeight > 3000){
            return 0.94
        }else if(viewHeight > 1000){
            return 0.93
        }else{
            return 0.92
        }
    }

    getSpeedFactorByHeight(viewHeight){
        if(viewHeight > 2000){
            return defaultParticleSystemOptions.speedFactor
        }else if(viewHeight > 1000){
            return 3.0
        }else{
            return 2.0
        }
    }

    setupEventListeners() {
        const that = this;

        this.camera.moveStart.addEventListener(function () {
            that.scene.primitives.show = false;
        });

        this.camera.moveEnd.addEventListener(function () {
            // 获取当前相机的视高
            const viewHeight = that.getViewHeight();
            // 根据视高(不同分辨率)设置合适的最大粒子数(解决不同分辨率下固定粒子数问题)
            let maxParticles = that.getMaxNumByHeight(viewHeight);
            // 根据视高设置合适的迹线宽度(设置高分辨率下迹线太宽影响可视化效果问题)
            let lineWidth = that.getLineWidthByHeight(viewHeight);
            // 根据视高设置合适的透明度(解决高分辨率下，观察某一局部地区的迹线颜色太亮影响可视化效果)
            let fadeOpacity = that.getOpacityByHeight(viewHeight);
            // 根据视高设置合适的速度因子(解决分辨率很高的情况下，固定速度因子带来的迹线速度太快，给人眼花缭乱的眩晕感)
            let speedFactor = that.getSpeedFactorByHeight(viewHeight);
            that.panel.maxParticles = maxParticles;
            that.panel.lineWidth = lineWidth;
            that.panel.fadeOpacity = fadeOpacity;
            that.panel.speedFactor = speedFactor;
            console.log('当前相机视角高度(单位 m):', viewHeight)
            console.log(that.panel.getUserInput())
            that.particleSystem.applyUserInput(that.panel.getUserInput());

            that.updateViewerParameters();
            that.particleSystem.applyViewerParameters(that.viewerParameters);
            that.scene.primitives.show = true;
        });

        var resized = false;
        window.addEventListener("resize", function () {
            resized = true;
            that.scene.primitives.show = false;
            that.scene.primitives.removeAll();
        });

        this.scene.preRender.addEventListener(function () {
            if (resized) {
                that.particleSystem.canvasResize(that.scene.context);
                resized = false;
                that.addPrimitives();
                that.scene.primitives.show = true;
            }
        });

        window.addEventListener('particleSystemOptionsChanged', function () {
            that.particleSystem.applyUserInput(that.panel.getUserInput());
        });
        window.addEventListener('layerOptionsChanged', function () {
            that.setGlobeLayer(that.panel.getUserInput());
        });
    }

    debug() {
        const that = this;

        var animate = function () {
            that.viewer.resize();
            that.viewer.render();
            requestAnimationFrame(animate);
        }

        var spector = new SPECTOR.Spector();
        spector.displayUI();
        spector.spyCanvases();

        animate();
    }
}
