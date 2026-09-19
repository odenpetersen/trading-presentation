#include <fstream>
#include <vector>
#include <random>
#include <iostream>

struct Node {
    int feature;
    float threshold;
    int prediction;
    Node *left, *right;
};

Node* load_tree(const char* file) {
    std::ifstream f(file);
    int n;
    f >> n;

    std::vector<Node*> nodes(n);
    for (int i = 0; i < n; ++i)
        nodes[i] = new Node;

    for (int i = 0; i < n; ++i) {
        int l, r;
        f >> nodes[i]->feature >> nodes[i]->threshold
          >> l >> r >> nodes[i]->prediction;
        if (l >= 0) {
            nodes[i]->left  = nodes[l];
            nodes[i]->right = nodes[r];
        } else {
            nodes[i]->left = nodes[i]->right = nullptr;
        }
    }

    return nodes[0];
}

int predict(Node* node, const float* x) {
    while (node->left)
        node = x[node->feature] < node->threshold
             ? node->left : node->right;
    return node->prediction;
}

int main() {
    Node* tree = load_tree("tree.txt");

    std::vector<float> x(32 * 10'000'000);
    std::mt19937 rng(1);
    for (float& v : x)
        v = std::generate_canonical<float, 10>(rng);

    int result = 0;
    for (int i = 0; i < 10'000'000; ++i)
        result += predict(tree, &x[i * 32]);

    std::cout << result << '\n';
}
