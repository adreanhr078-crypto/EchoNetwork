from pathlib import Path
import hashlib
import json
import struct
import sys

RUNTIME = "Assets/ElevenEleven/Opening/Stormworks/Observatory"

def aligned(data, pad=b"\0"):
    return data + pad * (-len(data) % 4)

def read_chunks(path):
    with path.open("rb") as source:
        assert source.read(4) == b"glTF"
        version, length = struct.unpack("<II",source.read(8))
        assert version == 2 and length == path.stat().st_size
        size, kind = struct.unpack("<I4s",source.read(8))
        assert kind == b"JSON"
        doc = json.loads(source.read(size))
        size, kind = struct.unpack("<I4s",source.read(8))
        assert kind == b"BIN\0"
        return doc, source.read(size)

def glb(doc, binary):
    fmt = json.dumps(doc,separators=(",",":"),ensure_ascii=False).encode("utf-8")
    encoded, data = aligned(fmt,b" "), aligned(binary)
    return b"glTF" + struct.pack("<IIII",2,28+len(encoded)+len(data),len(encoded),0x4E4F534A) + encoded + struct.pack("<I4s",len(data),b"BIN\0") + data

def references(node, view_map):
    if isinstance(node,dict):
        for key, value in node.items():
            if key == "bufferView":
                node[key]=view_map[value]
            else:
                references(value,view_map)
    if isinstance(node,list):
        for value in node:
            references(value,view_map)

def extract(source, output):
    doc, old_binary = read_chunks(source)
    old_views = doc["bufferViews"]
    roles = {}
    for material in doc.get("materials",[]):
        pbr=material.get("pbrMetallicRoughness",{})
        for group, key, color in ((pbr,"baseColorTexture","srgb"),(material,"emissiveTexture","srgb"),
                                 (pbr,"metallicRoughnessTexture","linear"),(material,"normalTexture","linear"),
                                 (material,"occlusionTexture","linear")):
            if key in group:
                index=doc["textures"][group[key]["index"]]["source"]
                assert index not in roles or roles[index]==color,(source.name,key,index)
                roles[index]=color

    removed=set()
    maps=[]
    folder = output.parent/"Maps"/output.stem
    folder.mkdir(parents=True,exist_ok=True)
    for index,image in enumerate(doc["images"]):
        codec=image.pop("mimeType")
        old=image.pop("bufferView")
        view=old_views[old]
        removed.add(old)
        assert view.get("buffer",0)==0
        start=view.get("byteOffset",0)
        pixels=old_binary[start:start+view["byteLength"]]
        file = folder / f"Map-{index}-{roles.get(index,'linear')}.{ {'image/png':'png','image/jpeg':'jpg'}[codec]}"
        file.write_bytes(pixels)
        image["uri"] = file.relative_to(output.parent).as_posix()
        maps.append({"path":image["uri"],"source_bytes":len(pixels),"sha256":hashlib.sha256(pixels).hexdigest()})

    remain, view_map, new_binary = [], {}, bytearray()
    for index, view in enumerate(old_views):
        if index in removed:
            continue
        assert view.get("buffer",0)==0
        start = view.get("byteOffset",0)
        view_map[index]=len(remain)
        remain.append({**view,"byteOffset":len(new_binary)})
        new_binary.extend(aligned(old_binary[start:start+view["byteLength"]]))
    del doc["bufferViews"]
    references(doc,view_map)
    doc["bufferViews"]=remain
    doc["buffers"][0]["byteLength"]=len(new_binary)
    staged=output.with_suffix(".glb-stage")
    staged.write_bytes(glb(doc,new_binary))
    staged.replace(output)
    return {"maps":maps,"geometry_container_sha256":hashlib.sha256(output.read_bytes()).hexdigest()}

project=Path(sys.argv[1])
inputs=[Path(p) for p in sys.argv[2:]]
sources=project/"Migration/ArtSources/MemoryObservatory"
result={}
for path in inputs:
    for source in sorted(path.glob("*.glb")):
        result[source.stem]=extract(source,project/RUNTIME/source.name)
        print(source.stem, len(result[source.stem]["maps"]),flush=True)
assert result, "Pass one or more folders with original textured GLBs"
manifest = sources/"Unity-Texture-Maps.json"
prior = json.loads(manifest.read_text(encoding="utf-8")) if manifest.is_file() else {}
prior.update(result)
manifest.write_text(json.dumps(prior,indent=2)+"\n",encoding="utf-8")
