import gemmi


def test_structure_is_trimmed_mmcif_with_position_map(client):
    for protein in client.get("/proteins").json():
        response = client.get(f"/structure/{protein['pdb_id']}")
        assert response.status_code == 200, response.text
        body = response.json()

        structure = gemmi.read_structure_string(body["cif"])
        structure.setup_entities()
        assert len(structure) == 1, "only the first model is served"
        residues = {
            (r.subchain, r.seqid.num, r.seqid.icode.strip()): r.name
            for chain in structure[0]
            for r in chain
        }

        wildtype = protein["wildtype_sequence"]
        positions = [m["position"] for m in body["residues"]]
        assert positions == sorted(set(positions))
        assert 1 <= positions[0] and positions[-1] <= len(wildtype)
        for mapping in body["residues"]:
            key = (mapping["chain_id"], mapping["auth_seq_id"], mapping["insertion_code"])
            assert key in residues, f"{protein['pdb_id']}: {key} not in served mmCIF"
            one_letter = gemmi.find_tabulated_residue(residues[key]).one_letter_code.upper()
            assert one_letter == wildtype[mapping["position"] - 1]


def test_unknown_structure_is_rejected(client):
    assert client.get("/structure/XXXX").status_code == 400


def _secondary_structure(structure, chain_name, residues):
    def covered(residue, start, end):
        return (
            start.chain_name == chain_name
            and not (residue.seqid < start.res_id.seqid)
            and not (end.res_id.seqid < residue.seqid)
        )

    labels = []
    for residue in residues:
        label = "-"
        if any(covered(residue, h.start, h.end) for h in structure.helices):
            label = "H"
        if any(covered(residue, s.start, s.end) for sheet in structure.sheets for s in sheet.strands):
            label = "E"
        labels.append(label)
    return "".join(labels)


def test_trimming_keeps_secondary_structure_of_served_residues(client):
    import main

    for protein in client.get("/proteins").json():
        pdb_id = protein["pdb_id"]
        served = gemmi.read_structure_string(client.get(f"/structure/{pdb_id}").json()["cif"])
        raw = gemmi.read_structure_string((main.STRUCTURE_CACHE_PATH / f"{pdb_id}.cif").read_text())
        chain = served[0][0]
        kept = {(r.seqid.num, r.seqid.icode) for r in chain}
        raw_residues = [r for r in raw[0][chain.name] if (r.seqid.num, r.seqid.icode) in kept]
        assert _secondary_structure(served, chain.name, list(chain)) == _secondary_structure(
            raw, chain.name, raw_residues
        ), pdb_id
