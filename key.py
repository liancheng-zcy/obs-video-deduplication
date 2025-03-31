def xor(a, b):
    result = 0
    bit = 1
    for i in range(8):
        bit_a = a % 2
        bit_b = b % 2
        if bit_a != bit_b:
            result += bit
        a //= 2
        b //= 2
        bit *= 2
    return result

def xor_encrypt(data, key):
    result = ""
    for i in range(len(data)):
        byte = ord(data[i])
        key_byte = ord(key[i % len(key)])
        result += chr(xor(byte, key_byte))
    return result

def simple_hash(data):
    hash_value = 0
    for char in data:
        hash_value = (hash_value * 31 + ord(char)) % 2**32
    return str(hash_value)

# 用户信息
user_id = input("请输入用户ID（例如 user123）: ")
expiration_days = int(input("请输入许可证有效天数（例如 365）: "))

import time
current_time = int(time.time())
expiration = str(current_time + expiration_days * 24 * 3600)
data = f"{user_id}:{expiration}"

key = "Kj9pL2mNx7vQ4tRwY8zB5cF1dH3gJ6k"  # 与 Lua 脚本一致的密钥
encrypted_data = xor_encrypt(data, key)
checksum = simple_hash(encrypted_data)

with open(f"license_{user_id}.key", "w") as f:
    f.write(f"{encrypted_data}:{checksum}")

print(f"已为用户 {user_id} 生成 license.key: {encrypted_data}:{checksum}")
print(f"到期时间: {time.strftime('%Y-%m-%d', time.localtime(int(expiration)))}")
print(f"文件已保存为: license_{user_id}.key")