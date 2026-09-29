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
