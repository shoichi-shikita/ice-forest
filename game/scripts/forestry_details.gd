extends Node3D

func _ready() -> void:
    var g = get_parent()
    var timber: Material = g.mat(Color(0.20, 0.14, 0.09))
    var red: Material = g.mat(Color(0.30, 0.055, 0.028))
    for pos in [Vector3(-4.4,0,-8), Vector3(-4.7,0,-28), Vector3(4.9,0,-42), Vector3(-4.3,0,-51)]:
        var stake := Node3D.new()
        stake.name = "BoundaryStake"
        stake.position = pos
        stake.rotation.z = 0.08 if pos.x < 0 else -0.12
        add_child(stake)
        g.cube(stake, Vector3(0.08,0.42,0.08), Vector3(0,0.14,0),timber)
        g.cube(stake, Vector3(0.082,0.09,0.082), Vector3(0,0.30,0),red)
        # 欠けと退色。番号や謎解きの印は付けない。
        g.cube(stake,Vector3(0.027,0.047,0.002),Vector3(0.015,0.30,0.042),timber)
    for side in [-1.0,1.0]:
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in range(120):
            var z0 := 3.0 - i * 0.47
            var z1 := z0 - 0.47
            var c0: float = sin((1.3-z0)/1.68*0.65)*0.27 + side*0.64
            var c1: float = sin((1.3-z1)/1.68*0.65)*0.27 + side*0.64
            var a := Vector3(c0-0.10,-0.035,z0)
            var b := Vector3(c0+0.10,-0.035,z0)
            var c := Vector3(c1-0.10,-0.035,z1)
            var d := Vector3(c1+0.10,-0.035,z1)
            for point in [a,b,c,b,d,c]: surface.add_vertex(point)
        surface.generate_normals()
        var rut := MeshInstance3D.new()
        rut.name = "WheelRut"
        rut.mesh = surface.commit()
        rut.material_override = g.mat(Color(0.035,0.029,0.019))
        add_child(rut)
    var pipe := Node3D.new()
    pipe.name = "AbandonedPolyPipe"
    add_child(pipe)
    var rubber: Material = g.mat(Color(0.012,0.014,0.013),0.82)
    var previous := Vector3(1.5,-0.025,-18.0)
    for i in range(1,26):
        var t := float(i)/25.0
        var point := Vector3(1.5 + t*1.9 + sin(t*TAU)*0.23,-0.025,-18.0-t*8.0)
        var direction := point-previous
        var segment: MeshInstance3D = g.cylinder(pipe,0.035,direction.length(),(point+previous)*0.5,rubber)
        (segment.mesh as CylinderMesh).cap_top = false
        (segment.mesh as CylinderMesh).cap_bottom = false
        segment.quaternion = Quaternion(Vector3.UP,direction.normalized())
        previous = point

